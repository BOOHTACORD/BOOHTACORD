package ru.boohtacord.voice.start

object VoicePlaybackAdmissionPolicy {
    fun permitsStart(active: Boolean, visible: Boolean): Boolean = active || visible
}
