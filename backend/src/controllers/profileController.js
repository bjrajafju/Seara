import supabase from "../services/supabase.js";

// Vai buscar utilizador
const getUserById = async (userId) => {
    const { data: user, error } = await supabase
        .from("users")
        .select("*")
        .eq("id", userId)
        .single();
    if (error || !user) throw new Error("Utilizador não encontrado");
    return user;
};

// Contagem de posts
const getPostsCount = async (userId) => {
    const { count } = await supabase
        .from("posts")
        .select("*", { count: "exact" })
        .eq("user_id", userId);
    return count || 0;
};

// Contagem de seguidores
const getFollowersCount = async (userId) => {
    const { count } = await supabase
        .from("followers")
        .select("*", { count: "exact" })
        .eq("user_id", userId);
    return count || 0;
};

// Contagem de following
const getFollowingCount = async (userId) => {
    const { count } = await supabase
        .from("followers")
        .select("*", { count: "exact" })
        .eq("follower_id", userId);
    return count || 0;
};

// Controller principal
export const getProfile = async (req, res) => {
    try {
        const userId = req.params.userId;

        const user = await getUserById(userId);
        const [postsCount, followersCount, followingCount] = await Promise.all([
            getPostsCount(userId),
            getFollowersCount(userId),
            getFollowingCount(userId),
        ]);

        const profile = {
            id: user.id,
            username: user.username,
            name: user.name,
            bio: user.bio,
            avatar_url: user.avatar,
            posts_count: postsCount,
            followers_count: followersCount,
            following_count: followingCount,
        };

        res.json(profile);
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: err.message });
    }
};

export const updateProfile = async (req, res) => {
    try {
        const userId = req.params.userId;
        const { name, username, bio, avatar } = req.body;

        // Verificar se o username já existe para outro utilizador
        const { data: existingUser, error: checkError } = await supabase
            .from("users")
            .select("id")
            .eq("username", username)
            .neq("id", userId)
            .single();

        if (existingUser) {
            return res.status(400).json({ error: "Username já existe" });
        }

        // Atualizar utilizador
        const { data, error } = await supabase
            .from("users")
            .update({
                name,
                username,
                bio,
                avatar,
                updated_at: new Date(),
            })
            .eq("id", userId)
            .select()
            .single();

        if (error) throw error;

        res.json(data);
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: err.message });
    }
};
export const followUser = async (req, res) => {
    try {
        const { followerId, followingId } = req.body;

        // verificar se já segue
        const { data: follows, error: checkError } = await supabase
            .from("followers")
            .select("id")
            .eq("follower_id", followerId)
            .eq("user_id", followingId)
            .single();
        if (follows) {
            return res.status(400);
        }
        if (checkError) throw checkError;

        // inserir follow na tabela de followers
        const { error } = await supabase.from("followers").insert({
            user_id: followingId,
            follower_id: followerId,
        });
        if (error) throw error;
        res.status(201);
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: err.message });
    }
};

// Lista todos os utilizadores (para dev/testing)
export const getAllUsers = async (req, res) => {
    try {
        const { data: users, error } = await supabase
            .from("users")
            .select("id, username, avatar");

        if (error) throw error;

        res.json(users ?? []);
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: err.message });
    }
};
