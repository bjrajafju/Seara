import supabase from "../services/supabase.js";
import { filterSystemUsers } from "../utils/helpers.js";

/// Profile controller for profile and relationship endpoints.
export const getProfile = async (req, res) => {
    try {
        const userId = req.params.userId;

        const { data, error } = await supabase
            .from("profiles_view")
            .select("*")
            .eq("id", userId)
            .single();

        if (error || !data) {
            return res.status(404).json({ error: "Utilizador não encontrado" });
        }

        return res.json({
            id: data.id,
            username: data.username,
            name: data.name,
            bio: data.bio,
            avatar_url: data.avatar,
            posts_count: data.posts_count,
            followers_count: data.followers_count,
            following_count: data.following_count,
        });
    } catch (err) {
        console.error(err);
        return res.status(500).json({ error: err.message });
    }
};

export const updateProfile = async (req, res) => {
    try {
        const userId = req.params.userId;
        const { name, username, bio, avatar } = req.body;

        /// Prevents username conflicts with other users.
        const { data: existingUser, error: checkError } = await supabase
            .from("users")
            .select("id")
            .eq("username", username)
            .neq("id", userId)
            .single();

        if (existingUser) {
            return res.status(400).json({ error: "Username já existe" });
        }

        /// Updates profile fields for the current user.
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
export const isFollowing = async (req, res) => {
    try {
        const { followerId, followingId } = req.body;

        if (!followerId || !followingId) {
            return res
                .status(400)
                .json({ error: "Missing followerId or followingId" });
        }

        const { data, error } = await supabase
            .from("followers")
            .select("id")
            .eq("follower_id", followerId)
            .eq("user_id", followingId)
            .maybeSingle();

        if (error) throw error;

        return res.json({ isFollowing: !!data });
    } catch (err) {
        console.error(err);
        return res.status(500).json({ error: err.message });
    }
};

export const followUser = async (req, res) => {
    try {
        const { followerId, followingId } = req.body;

        if (!followerId || !followingId) {
            return res
                .status(400)
                .json({ error: "Missing followerId or followingId" });
        }

        const { data, error } = await supabase
            .from("followers")
            .insert({
                user_id: followingId,
                follower_id: followerId,
            })
            .select();

        if (error) {
            if (error.code === "23505") {
                return res.status(409).json({ error: "Already following" });
            }
            throw error;
        }

        return res.status(201).json(data);
    } catch (err) {
        console.error(err);
        return res.status(500).json({ error: err.message });
    }
};

export const unfollowUser = async (req, res) => {
    try {
        const { followerId, followingId } = req.body;

        /// Removes follow record from followers table.
        const { error } = await supabase
            .from("followers")
            .delete()
            .eq("follower_id", followerId)
            .eq("user_id", followingId);
        if (error) throw error;
        return res.sendStatus(200);
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: err.message });
    }
};

/// Returns all users with follow relationship context.
export const getAllUsers = async (req, res) => {
    try {
        const { data: users, error } = await supabase
            .from("users")
            .select("id, username, avatar");

        if (error) throw error;

        const filteredUsers = filterSystemUsers(users ?? []);

        res.json(filteredUsers);
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: err.message });
    }
};

export const getUsersWithRelationship = async (req, res) => {
    try {
        const { userId } = req.params;

        if (!userId) {
            return res.status(400).json({ error: "User ID obrigatorio." });
        }

        /// Loads all users except the current user.
        const { data: users, error: usersError } = await supabase
            .from("users")
            .select("id, username, name, avatar")
            .neq("id", userId);

        if (usersError) throw usersError;

        /// Loads users followed by the current user.
        const { data: iFollow, error: iFollowError } = await supabase
            .from("followers")
            .select("user_id")
            .eq("follower_id", userId);

        if (iFollowError) throw iFollowError;

        /// Loads users that follow the current user.
        const { data: followsMe, error: followsMeError } = await supabase
            .from("followers")
            .select("follower_id")
            .eq("user_id", userId);

        if (followsMeError) throw followsMeError;

        const iFollowIds = new Set(iFollow.map((f) => f.user_id));
        const followsMeIds = new Set(followsMe.map((f) => f.follower_id));

        const filteredUsers = filterSystemUsers(users ?? []);

        const formatted = filteredUsers.map((user) => ({
            id: user.id,
            username: user.username,
            name: user.name,
            avatar_url: user.avatar,
            i_follow: iFollowIds.has(user.id),
            follows_me: followsMeIds.has(user.id),
        }));

        res.json(formatted);
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: err.message });
    }
};
