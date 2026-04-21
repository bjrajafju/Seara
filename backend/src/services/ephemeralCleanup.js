import supabase from "./supabase.js";

/**
 * Ephemeral message cleanup — runs every 15 minutes.
 * Deletes messages whose expires_at has passed.
 * Fully DBMS-independent (runs in Node.js, not pg_cron).
 */
const cleanupExpiredMessages = async () => {
    try {
        const now = new Date().toISOString();

        const { data: expired, error: fetchError } = await supabase
            .from("messages")
            .select("id")
            .not("expires_at", "is", null)
            .lt("expires_at", now)
            .limit(500);

        if (fetchError) {
            console.error("[EphemeralCleanup] Fetch error:", fetchError);
            return;
        }

        if (!expired || expired.length === 0) return;

        const ids = expired.map((m) => m.id);

        const { error: deleteError } = await supabase
            .from("messages")
            .delete()
            .in("id", ids);

        if (deleteError) {
            console.error("[EphemeralCleanup] Delete error:", deleteError);
            return;
        }

        console.log(
            `[EphemeralCleanup] Deleted ${ids.length} expired messages.`,
        );
    } catch (err) {
        console.error("[EphemeralCleanup] Unexpected error:", err);
    }
};

/// Cleanup interval in milliseconds.
const CLEANUP_INTERVAL = 15 * 60 * 1000;

export const startEphemeralCleanup = () => {
    console.log("[EphemeralCleanup] Started — runs every 15 minutes.");
    /// Run once immediately on startup
    cleanupExpiredMessages();
    /// Then every 15 minutes
    setInterval(cleanupExpiredMessages, CLEANUP_INTERVAL);
};
