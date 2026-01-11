import supabase from "../services/supabase.js";

// REGISTAR
export const register = async (req, res) => {
    let { email, password } = req.body || {};
    if (typeof email === "string") email = email.trim().toLowerCase();

    if (!email || !password) {
        return res
            .status(400)
            .json({ error: "Email e password são obrigatórios." });
    }

    try {
        // 1. Criar no Supabase Auth
        const { data, error } = await supabase.auth.signUp({
            email,
            password,
        });

        if (error || !data.user) {
            return res.status(400).json({ error: error?.message });
        }

        const authUserId = data.user.id; // UUID

        // 2. Criar utilizador na public.users
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

        // 3. Resposta limpa
        res.status(201).json({
            user: {
                id: appUser.id, // BIGINT
                auth_id: authUserId, // UUID
                email: appUser.email,
            },
        });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: "Erro interno do servidor." });
    }
};

// LOGIN
export const login = async (req, res) => {
    const { email, password } = req.body;

    if (!email || !password) {
        return res
            .status(400)
            .json({ error: "Email e password são obrigatórios." });
    }

    try {
        // 1. Login Supabase Auth
        const { data, error } = await supabase.auth.signInWithPassword({
            email,
            password,
        });

        if (error || !data.user) {
            return res.status(400).json({ error: error?.message });
        }

        const authUserId = data.user.id;

        // 2. Buscar utilizador da app
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

        // 3. Responder com session + app user id
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

// Função auxiliar para gerar username único
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
