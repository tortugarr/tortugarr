package org.moonfin.androidtv

/**
 * The arithmetic behind a trailing-edge debounce with a ceiling.
 *
 * A capability listener fires in bursts, so answering any one event on its
 * own describes hardware that is mid-change. Waiting for the trailing edge
 * means the one emission that survives reports settled hardware, and the
 * ceiling stops a source that keeps flapping from starving it entirely.
 *
 * The caller owns the clock and the posting: every event goes through
 * [onEvent] and the caller reposts its one runnable at the uptime returned,
 * then reports [fired] when that runnable runs or is cancelled.
 */
internal class BurstCoalescer(
    private val debounceMs: Long,
    private val maxWaitMs: Long,
) {
    private var deadlineMs: Long? = null

    /** The uptime the pending emit should run at, given an event at [nowMs]. */
    fun onEvent(nowMs: Long): Long {
        // Armed by the first event of a burst and left alone by the rest, so
        // the ceiling measures from when the burst started.
        val deadline = deadlineMs ?: (nowMs + maxWaitMs).also { deadlineMs = it }
        return minOf(nowMs + debounceMs, deadline)
    }

    /** Ends the burst. The next event opens a new one with a fresh ceiling. */
    fun fired() {
        deadlineMs = null
    }
}
