import supabase from "../services/supabase.js";

/// Registers a new user account.
export const register = async (req, res) => {
    let { email, password } = req.body || {};
    if (typeof email === "string") email = email.trim().toLowerCase();

    if (!email || !password) {
        return res
            .status(400)
            .json({ error: "Email e password são obrigatórios." });
    }

    try {
        const { data, error } = await supabase.auth.signUp({
            email,
            password,
        });

        if (error || !data.user) {
            return res.status(400).json({ error: error?.message });
        }

        const authUserId = data.user.id; /// UUID

        const baseUsername = email.split("@")[0];
        const username = await generateUsername(baseUsername);

        const { data: appUser, error: dbError } = await supabase
            .from("users")
            .insert({
                auth_id: authUserId,
                email: email,
                name: email.split("@")[0],
                username: username,
            })
            .select()
            .single();
        if (dbError) {
            console.log("DB ERROR:", dbError);
            return res
                .status(500)
                .json({ error: "Erro ao criar utilizador da app" });
        }

        res.status(201).json({
            user: {
                id: appUser.id, /// BIGINT
                auth_id: authUserId, /// UUID
                email: appUser.email,
            },
        });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: "Erro interno do servidor." });
    }
};

/// Logs in a user and returns app session data.
export const login = async (req, res) => {
    const { email, password } = req.body;

    if (!email || !password) {
        return res
            .status(400)
            .json({ error: "Email e password são obrigatórios." });
    }

    try {
        const { data, error } = await supabase.auth.signInWithPassword({
            email,
            password,
        });

        if (error || !data.user) {
            return res.status(400).json({ error: error?.message });
        }

        const authUserId = data.user.id;

        const { data: appUser, error: userError } = await supabase
            .from("users")
            .select("id")
            .eq("auth_id", authUserId)
            .single();

        if (userError || !appUser) {
            return res
                .status(404)
                .json({ error: "Utilizador da app não encontrado" });
        }

        res.json({
            session: data.session,
            user: {
                id: appUser.id,
                username: appUser.username,
            },
        });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: "Erro interno no servidor." });
    }
};

/// Generates a unique username from the requested base value.
const generateUsername = async (base) => {
    let username = base.toLowerCase().replace(/[^a-z0-9_]/g, "");
    let count = 0;

    while (true) {
        const { data: existing } = await supabase
            .from("users")
            .select("id")
            .eq("username", count === 0 ? username : `${username}${count}`)
            .single();

        if (!existing) break;
        count++;
    }

    return count === 0 ? username : `${username}${count}`;
};
