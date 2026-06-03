import supabase from "../backend/src/services/supabase.js";

async function checkDb() {
    try {
        const { count, error } = await supabase
            .from("daily_questions")
            .select("*", { count: "exact", head: true });
        
        if (error) {
            console.error("Erro ao acessar daily_questions:", error);
        } else {
            console.log("Total de perguntas em daily_questions:", count);
        }

        const { data: routes, error: rError } = await supabase
            .from("daily_questions")
            .select("date")
            .not("date", "is", null);
        
        console.log("Datas já atribuídas:", routes?.map(r => r.date));
    } catch (e) {
        console.error("Erro fatal:", e);
    }
}

checkDb();
