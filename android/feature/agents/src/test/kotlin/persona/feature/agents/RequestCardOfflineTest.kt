package persona.feature.agents

import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithText
import androidx.test.ext.junit.runners.AndroidJUnit4
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import persona.core.contracts.Interaction
import persona.core.designsystem.AppStyle
import persona.core.designsystem.PersonaTheme
import java.time.Instant

/**
 * A request card in the Agents list while its hub is unreachable (#2483): Allow and Deny stay greyed out, and the card says
 * why, as the request's full page does, instead of buttons that are just disabled.
 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [35], qualifiers = "en-w400dp-h1200dp")
class RequestCardOfflineTest {
    @get:Rule val rule = createComposeRule()

    private val now = Instant.parse("2026-11-09T08:00:00Z")
    private val offline = "Connect to the hub to send your choice"
    private val card = Interaction("ix_build", machineId = "macbook", sessionId = "tests", sessionTitle = "Run the test suite",
        kind = "permission", toolName = "Bash", expiresAt = now.plusSeconds(600).toString(),
        toolInput = buildJsonObject { put("command", "swift test"); put("description", "Run the package tests") })

    private fun show(online: Boolean, request: Interaction = card, approvable: Boolean = true) = rule.setContent {
        PersonaTheme(style = AppStyle.Glass, darkTheme = false, reduceMotion = true) {
            RequestCard(request, "MacBook", AgentsMetadata(), now, online = online, delivery = null, onOpen = {},
                onAnswer = { _, _, _, _ -> }, approvable = approvable)
        }
    }

    @Test fun offlineTheCardSaysWhyItsButtonsAreGreyedOut() {
        show(online = false)
        rule.onNodeWithText(offline).assertExists()
        rule.onNodeWithText("Allow").assertIsNotEnabled()
        rule.onNodeWithText("Deny").assertIsNotEnabled()
    }

    @Test fun onlineTheCardSaysNothingAndItsButtonsWork() {
        show(online = true)
        rule.onAllNodesWithText(offline).assertCountEquals(0)
        rule.onNodeWithText("Allow").assertIsEnabled()
        rule.onNodeWithText("Deny").assertIsEnabled()
    }

    @Test fun anExpiredCardDoesNotBlameTheConnection() {
        show(online = false, request = card.copy(expiresAt = now.minusSeconds(1).toString()))
        rule.onAllNodesWithText(offline).assertCountEquals(0)
    }

    @Test fun aCardThePhoneCannotApproveSaysThatInstead() {
        show(online = false, approvable = false)
        rule.onAllNodesWithText(offline).assertCountEquals(0)
    }
}
