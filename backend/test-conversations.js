import { createClient } from '@supabase/supabase-js';

// Test the listConversations endpoint directly
const testListConversations = async () => {
    const supabaseUrl = 'http://localhost:3000'; // Adjust if different
    const supabaseKey = 'your-anon-key'; // You'll need to provide this
    
    const supabase = createClient(supabaseUrl, supabaseKey);

    try {
        // Test 1: Check if user has conversation_user entries
        console.log('=== Testing conversation_user table ===');
        const { data: userConvs, error: userError } = await supabase
            .from('conversation_user')
            .select('*')
            .eq('user_id', 1) // Replace with actual user ID
            .eq('is_archived', false);
        
        console.log('User conversations:', userConvs?.length || 0);
        console.log('User conversations data:', userConvs);
        console.log('User error:', userError);

        // Test 2: Check if conversations exist
        if (userConvs && userConvs.length > 0) {
            const conversationIds = userConvs.map(c => c.conversation_id);
            console.log('Conversation IDs:', conversationIds);
            
            const { data: conversations, error: convError } = await supabase
                .from('conversations')
                .select('*')
                .in('id', conversationIds);
            
            console.log('Conversations found:', conversations?.length || 0);
            console.log('Conversations data:', conversations);
            console.log('Conversations error:', convError);
        }

    } catch (error) {
        console.error('Test error:', error);
    }
};

// If you're using node directly
if (typeof module !== 'undefined' && module.exports) {
    module.exports = { testListConversations };
} else {
    testListConversations();
}
