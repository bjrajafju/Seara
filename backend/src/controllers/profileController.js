import supabase from "../services/supabase.js";

// Funções auxiliares
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
            username: user.name,
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
