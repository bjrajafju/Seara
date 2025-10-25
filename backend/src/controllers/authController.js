import supabase from "../services/supabase.js";

// Regex de Validação
const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

// Função de Validação
const isValidPassword = (password) => password && password.length >= 6;

// REGISTAR
export const register = async (req, res) => {
  console.log("POST /auth/register - raw body:", req.body);

  // Normalizar entrada
  let { email, password } = req.body || {};
  if (typeof email === 'string') email = email.trim().toLowerCase();
  console.log("Normalized:", { email, password: password ? '***' : null });

  // Validação
  if (!email || !password) {
    return res.status(400).json({ error: "Email e password são obrigatórios." });
  }

  if (!emailRegex.test(email)) {
    return res.status(400).json({ error: "Email inválido." });
  }

  if (!isValidPassword(password)) {
    return res.status(400).json({ error: "Password deve ter pelo menos 6 caracteres." });
  }

  try {
    const { data, error } = await supabase.auth.signUp({
      email,
      password,
    });

    console.log("Supabase register result:", { data, error });

    if (error) {
      // log detalhado para debug
      console.error("Supabase error code:", error.code, "message:", error.message);
      return res.status(error.status || 400).json({ error: error.message });
    }

    res.status(201).json({ user: data.user });
  } catch (err) {
    console.error("Erro no register:", err);
    res.status(500).json({ error: "Erro interno no servidor." });
  }
};

// LOGIN
export const login = async (req, res) => {
  const { email, password } = req.body;

  // Validação
  if (!email || !password) {
    return res.status(400).json({ error: "Email e password são obrigatórios." });
  }

  try {
    const { data, error } = await supabase.auth.signInWithPassword({
      email,
      password,
    });

    if (error) return res.status(400).json({ error: error.message });

    res.json({ user: data.user, session: data.session });
  } catch (err) {
    console.error("Erro no login:", err);
    res.status(500).json({ error: "Erro interno no servidor." });
  }
};
