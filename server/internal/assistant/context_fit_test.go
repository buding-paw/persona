package assistant

import (
	"strings"
	"testing"
	"time"

	"github.com/nwverse/persona/server/internal/prompts"
)

// bigSnapshot fills every section the snapshot can carry, each at its longest (#3203).
func bigSnapshot() prompts.Snapshot {
	line := strings.Repeat("x", 400)
	agents := func(n int, machine string) []prompts.SnapshotAgent {
		out := make([]prompts.SnapshotAgent, n)
		for i := range out {
			out[i] = prompts.SnapshotAgent{Label: "assistant › work", Machine: machine, Session: "01a1c3f3", Line: line,
				Link: "http://hub.example:18660/s/hub-1/01a1c3f3"}
		}
		return out
	}
	tasks := make([]prompts.SnapshotTask, 12)
	for i := range tasks {
		tasks[i] = prompts.SnapshotTask{ID: "todo_1", Title: "落一份很长的报告", State: "在做", Last: line, Doing: line}
	}
	unaccepted := make([]prompts.SnapshotAccept, 8)
	for i := range unaccepted {
		unaccepted[i] = prompts.SnapshotAccept{Title: "上线了", Verdict: line, Changed: line, Since: time.Now()}
	}
	now := time.Now()
	return prompts.Snapshot{
		Now: now, Zone: "Asia/Shanghai",
		Machines: []prompts.SnapshotMachine{{Name: "the hub machine", ID: "hub-1", Online: true}},
		Needs:    agents(6, "hub-1"), Unread: agents(6, "build-1"), Awaiting: agents(4, "build-1"),
		Waiting: agents(6, "build-2"), Done: agents(20, "build-3"), Muted: agents(4, "build-4"),
		Working: agents(12, "hub-1"), Workflows: []prompts.SnapshotWorkflow{{Agent: "assistant › a", Machine: "build-1", Session: "s1", Name: "audit", Phase: "Verify", PhaseIndex: 2, Phases: 2, Done: 1, Started: 2, For: "3 minutes"}},
		Chats:    &prompts.SnapshotChats{AtMe: []prompts.SnapshotChat{{Name: "Team", Unread: 3, Preview: line}}, Other: []prompts.SnapshotChat{{Name: "Ops", Unread: 9}}},
		Calendar: &prompts.SnapshotCalendar{Events: []prompts.SnapshotEvent{{Start: now, End: now.Add(time.Hour), Title: "Sync"}}},
		KB:       strings.Repeat("知识库条目很长很长。", 200),
		Tasks:    tasks, Unaccepted: unaccepted, UnacceptedTotal: 12,
		Approvals: []prompts.SnapshotApproval{{ID: "todo_2", Title: "合并", Stage: "CI 绿", Gate: "等你点头"}},
		Plans:     []prompts.SnapshotPlan{{Titles: []string{"a", "b"}, Tasks: 2}},
		Routines:  []prompts.SnapshotRoutine{{Label: "早报", Rule: "每天 09:00"}},
		Missed:    []prompts.SnapshotMiss{{Label: "清单", Why: line}},
	}
}

func TestFitSnapshotStaysInBudget(t *testing.T) {
	s := bigSnapshot()
	before := len(prompts.RenderSnapshot(s))
	if before <= snapshotBudget {
		t.Fatalf("the fixture has to be over the budget to prove anything (got %d)", before)
	}
	rendered := fitSnapshot(&s)
	got := len(rendered)
	if got > snapshotBudget {
		t.Fatalf("rendered snapshot is %d chars, budget is %d", got, snapshotBudget)
	}
	// What waits for the user is what the block is for: it survives every drop.
	if len(s.Needs) != 6 {
		t.Fatalf("the agents waiting for the user were dropped (%d left)", len(s.Needs))
	}
	// Dropped sections keep their count in the header line, so "0" never reads as "nothing happened".
	if !strings.Contains(rendered, "完成未看") {
		t.Fatal("the counts line went missing")
	}
}

func TestFitSnapshotClipsLongLines(t *testing.T) {
	s := bigSnapshot()
	fitSnapshot(&s)
	for _, a := range s.Needs {
		if n := len([]rune(a.Line)); n > snapshotLine+1 {
			t.Fatalf("a line kept %d characters, the limit is %d", n, snapshotLine)
		}
	}
}

func TestFitSnapshotLeavesASmallSnapshotAlone(t *testing.T) {
	s := prompts.Snapshot{Now: time.Now(), Zone: "Asia/Shanghai",
		Needs:    []prompts.SnapshotAgent{{Label: "assistant › a", Machine: "build-1", Session: "s1", Line: "在等"}},
		Routines: []prompts.SnapshotRoutine{{Label: "早报", Rule: "每天 09:00"}}}
	fitSnapshot(&s)
	if len(s.Needs) != 1 || len(s.Routines) != 1 {
		t.Fatal("a snapshot under the budget lost a section")
	}
	if s.Needs[0].Line != "在等" {
		t.Fatalf("a short line was changed: %q", s.Needs[0].Line)
	}
}

// The fixture must stay representative: if the real template grows a section, this catches a fitter that ignores it.
func TestFitSnapshotCoversEverySection(t *testing.T) {
	rendered := prompts.RenderSnapshot(bigSnapshot())
	for _, marker := range []string{"等用户验收", "做完的", "已屏蔽", "等用户点", "知识库", "未读会话", "定时任务"} {
		if !strings.Contains(rendered, marker) {
			t.Fatalf("the fixture does not reach %q, the fitter may not cover it", marker)
		}
	}
}
