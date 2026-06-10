import supabase from "./src/services/supabase.js";

async function run() {
  const { data: conversation, error: convError } = await supabase
      .from("conversations")
      .select("id, name, is_group, created_at, updated_at")
      .eq("id", 27)
      .single();

  if (convError) {
      console.error(convError);
      return;
  }

  const { data: settings } = await supabase
      .from("conversation_settings")
      .select("*")
      .eq("conversation_id", 27)
      .single();

  const responseData = {
      ...conversation,
      image: settings?.image || null,
      description: settings?.description || null,
  };

  console.log("Response Data for Details (ID 27):");
  console.log(JSON.stringify(responseData, null, 2));
}

run();


