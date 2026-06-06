import supabase from "../backend/src/services/supabase.js";

async function testInsert() {
    try {
        // 1. Pegar um user real
        const { data: user } = await supabase.from("users").select("auth_id").limit(1).single();
        if (!user) {
            console.log("Nenhum utilizador encontrado para teste.");
            return;
        }
        const userId = user.auth_id;

        // 2. Pegar a pergunta de hoje
        const { data: question } = await supabase.from("daily_questions").select("*").eq("date", "2026-06-03").single();
        if (!question) {
            console.log("Nenhuma pergunta encontrada para hoje.");
            return;
        }
        console.log("Pergunta completa:", question);
        const questionId = question.id;

        console.log(`Testando insert para User: ${userId}, Question: ${questionId}`);

        // 3. Tentar inserir (se já existir vai dar erro de PK, o que é esperado se já respondi)
        const { data, error } = await supabase
            .from("user_daily_answers")
            .insert({
                user_id: userId,
                question_id: questionId,
                selected_option: "A",
                is_correct: true
            })
            .select();
        
        if (error) {
            console.error("Erro no INSERT:", error);
        } else {
            console.log("INSERT funcionou!", data);
        }

    } catch (e) {
        console.error("Erro no script de teste:", e);
    }
}

testInsert();
