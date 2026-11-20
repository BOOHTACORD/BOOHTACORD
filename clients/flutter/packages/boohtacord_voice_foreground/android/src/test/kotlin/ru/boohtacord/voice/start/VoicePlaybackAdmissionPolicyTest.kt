package ru.boohtacord.voice.start

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class VoicePlaybackAdmissionPolicyTest {
    @Test fun visibleActivityCanStartPlaybackService() {
        assertTrue(VoicePlaybackAdmissionPolicy.permitsStart(false, true))
    }

    @Test fun freshBackgroundStartIsRejected() {
        assertFalse(VoicePlaybackAdmissionPolicy.permitsStart(false, false))
    }

    @Test fun activePlaybackCanContinueInBackground() {
        assertTrue(VoicePlaybackAdmissionPolicy.permitsStart(true, false))
    }
}
