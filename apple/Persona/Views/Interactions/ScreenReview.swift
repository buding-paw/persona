import SwiftUI

/// How an answer from a screen card of several questions goes out (#2970). By its option, so the hub's history names
/// what was picked; as its keys when it may be the last answer, because the node presses the review tab's Submit
/// answers after an answer that names its option, and the user reviews first.
nonisolated enum ScreenAnswerRoute {
    /// A choice tapped.
    static func choice(_ o: ScreenParser.Dialog.Option, _ d: ScreenParser.Dialog, step: Int?, hubRead: Bool) -> Resolution {
        guard hubRead, !ScreenStepsLogic.submitsAll(d, current: step) else { return Resolution(keys: [o.key]) }
        return Resolution(option: o.key)
    }

    /// Words for "Type something.": words already in its field are cleared first (to the end, then back to the start,
    /// as the node clears a multi-select field), which only keys can say.
    static func typed(_ o: ScreenParser.Dialog.Option, text: String, _ d: ScreenParser.Dialog, step: Int?, hubRead: Bool) -> Resolution {
        let filled = !(o.text ?? "").isEmpty
        if hubRead, !filled, !ScreenStepsLogic.submitsAll(d, current: step) { return Resolution(text: text, option: o.key) }
        return Resolution(keys: ["enter"], text: text, preKeys: filled ? [o.key, "ctrl+e", "ctrl+u"] : [o.key])
    }

    /// The answer as the review shows it: the labels picked, then the words.
    static func summary(_ d: ScreenParser.Dialog, keys: [String], text: String) -> String {
        let labels = d.options.filter { keys.contains($0.key) && $0.kind == .plain }.map { QuestionOption.display($0.label).0 }
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return (labels + (t.isEmpty ? [] : [t])).joined(separator: String(localized: ", ", comment: "Separator between items in a list"))
    }
}

/// The answers of a dialog of several questions before they are submitted (#2970): the terminal's review tab, or the
/// review the app shows before the last multi-select answer. A row per question; one not answered says so, and the main
/// button then takes you to it, with Submit Without Them under it.
struct ScreenReview: View {
    var rows: [ScreenReviewRow]
    /// What is being sent (a spinner on its button).
    var sending: String?
    var back: (() -> Void)?
    var submit: () -> Void
    /// Go and answer that question.
    var answer: ((ScreenReviewRow) -> Void)?

    private var missing: ScreenReviewRow? { rows.first { $0.answer == nil } }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            Text("Review Your Answers").font(Theme.Font.heading)
            VStack(spacing: 0) {
                ForEach(rows) { row in
                    if row.index != rows.first?.index { Divider().padding(.leading, Theme.Space.l) }
                    line(row)
                }
            }
            .background(Theme.Fill.well, in: .rect(cornerRadius: Theme.Radius.card, style: .continuous))
            .accessibilityIdentifier("screen-review")
            footer
        }
    }

    private func line(_ row: ScreenReviewRow) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Text(row.label.isEmpty ? (row.question ?? "") : row.label)
                .font(Theme.Font.labelStrong)
                .foregroundStyle(.secondary)
            switch row.answer {
            case nil:
                Label("Not answered", systemImage: Theme.Icon.error)
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.cautionText)
            case let a? where a.isEmpty:
                Text("Answered on the computer").font(Theme.Font.body).foregroundStyle(.secondary)
            case let a?:
                Text(a).font(Theme.Font.body).fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.Space.l)
        .padding(.vertical, Theme.Space.m)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var footer: some View {
        HStack(spacing: Theme.Space.m) {
            if let back {
                Button { back() } label: { Text("Previous [Interaction Views 39b1c2]").lineLimit(1) }
                    .themedButton()
                    .accessibilityIdentifier("screen-review-back")
            }
            Spacer(minLength: 0)
            if let missing, let answer {
                Button { answer(missing) } label: {
                    HStack(spacing: Theme.Space.sm) {
                        if sending == "walk" { ProgressView().controlSize(.small).tint(.white) }
                        Text("Answer “\(missing.label)”").lineLimit(1).minimumScaleFactor(0.8)
                    }
                    .padding(.horizontal, Theme.Space.s)
                }
                .themedButton(prominent: true)
                .accessibilityIdentifier("screen-review-answer")
            } else {
                Button { submit() } label: {
                    HStack(spacing: Theme.Space.sm) {
                        if sending == "submit" { ProgressView().controlSize(.small).tint(.white) }
                        Text("Submit \(rows.count) Answers").lineLimit(1).minimumScaleFactor(0.8)
                    }
                    .padding(.horizontal, Theme.Space.s)
                }
                .themedButton(prominent: true)
                .accessibilityIdentifier("screen-review-submit")
            }
        }
        .controlSize(.regular)
        .disabled(sending != nil)
        if missing != nil, answer != nil {
            HStack {
                Spacer(minLength: 0)
                Button { submit() } label: { Text("Submit Without Them").lineLimit(1) }
                    .buttonStyle(.plain)
                    .font(Theme.Font.captionMedium)
                    .foregroundStyle(Theme.accent)
                    .disabled(sending != nil)
                    .accessibilityIdentifier("screen-review-submit-anyway")
            }
        }
    }
}

/// While the card waits for the next question of its dialog.
struct ScreenMoving: View {
    var body: some View {
        HStack(spacing: Theme.Space.sm) {
            ProgressView().controlSize(.small)
            Text("Switching questions…").font(Theme.Font.captionMedium).foregroundStyle(.secondary).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("screen-moving")
    }
}
