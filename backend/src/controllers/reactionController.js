import supabase from "../services/supabase.js";

/// Adds or removes a reaction atomically.
export const toggleMessageReaction = async (req, res) => {
    const messageId = Number(req.params.id);
    const { userId, reaction } = req.body || {};

    if (!messageId || !userId || !reaction) {
        return res.status(400).json({ error: "Dados inválidos para reação." });
    }

    try {
        const { data: message, error: messageErr } = await supabase
            .from("messages")
            .select("id, conversation_id")
            .eq("id", messageId)
            .single();

        if (messageErr || !message) {
            return res.status(404).json({ error: "Mensagem não encontrada." });
        }

        const { error: insertErr } = await supabase
            .from("message_reactions")
            .insert({
                message_id: messageId,
                user_id: userId,
                reaction,
            });

        let added = true;
        if (insertErr) {
            if (insertErr.code !== "23505") throw insertErr;

            const { error: deleteErr } = await supabase
                .from("message_reactions")
                .delete()
                .eq("message_id", messageId)
                .eq("user_id", userId)
                .eq("reaction", reaction);

            if (deleteErr) throw deleteErr;
            added = false;
        }

        return res.status(200).json({
            message_id: messageId,
            conversation_id: message.conversation_id,
            reaction,
            added,
        });
    } catch (err) {
        console.error("toggleMessageReaction:", err);
        return res.status(500).json({ error: "Erro ao alternar reação." });
    }
};
