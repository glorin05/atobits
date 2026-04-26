export default {
  async fetch(request, env) {
    if (request.method !== 'POST') {
      return json({ error: 'Method not allowed' }, 405);
    }

    const auth = request.headers.get('authorization') || '';
    const expectedToken = (env.COACH_API_TOKEN || '').trim();
    if (expectedToken) {
      const expectedAuth = `Bearer ${expectedToken}`;
      if (auth !== expectedAuth) {
        return json({ error: 'Unauthorized' }, 401);
      }
    }

    const groqKey = (env.GROQ_API_KEY || '').trim();
    if (!groqKey) {
      return json({ error: 'Server not configured: missing GROQ_API_KEY' }, 500);
    }

    let body;
    try {
      body = await request.json();
    } catch {
      return json({ error: 'Invalid JSON body' }, 400);
    }

    const systemPrompt = String(body?.systemPrompt || '').trim();
    const conversation = Array.isArray(body?.conversation) ? body.conversation : [];

    if (!systemPrompt || conversation.length === 0) {
      return json({ error: 'Missing systemPrompt or conversation' }, 400);
    }

    const model = (env.GROQ_MODEL || 'llama-3.1-8b-instant').trim();

    const groqRes = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${groqKey}`,
      },
      body: JSON.stringify({
        model,
        temperature: 0.7,
        messages: [
          { role: 'system', content: systemPrompt },
          ...conversation,
        ],
      }),
    });

    const text = await groqRes.text();
    if (!groqRes.ok) {
      const fallback = buildFallbackReply(conversation);
      return json({ reply: fallback });
    }

    let decoded;
    try {
      decoded = JSON.parse(text);
    } catch {
      const fallback = buildFallbackReply(conversation);
      return json({ reply: fallback });
    }

    const reply =
      decoded?.choices?.[0]?.message?.content?.toString().trim() || '';

    if (!reply) {
      const fallback = buildFallbackReply(conversation);
      return json({ reply: fallback });
    }

    return json({ reply });
  },
};

function buildFallbackReply(conversation) {
  const lastUser = [...conversation]
    .reverse()
    .find((m) => (m?.role || '').toString().toLowerCase() === 'user');
  const text = (lastUser?.content || '').toString().trim();
  const lower = text.toLowerCase();

  if (lower.includes('add') && lower.includes('habit')) {
    const title = pickHabitTitle(lower);
    return `I added a starter habit for you so you can keep momentum today.\n\nACTIONS_JSON:{"actions":[{"type":"add_habit","title":"${escapeJson(
      title,
    )}","description":"Small, doable daily step","category":"General","timeOfDay":"anytime","iconKey":"mi:check"}]}`;
  }

  if (
    lower.includes('sad') ||
    lower.includes('stress') ||
    lower.includes('overwhelm')
  ) {
    return 'I am here with you. Let us keep it simple: do one tiny habit in the next 5 minutes, then come back and we will plan the next step together.';
  }

  if (lower.includes('plan') || lower.includes('productivity')) {
    return 'Quick plan: 1) Do your hardest habit first (10 minutes). 2) Complete one easy habit after that. 3) Check off one more before sleep.';
  }

  return 'I am temporarily running in backup coach mode. Tell me one goal for today and I will convert it into a tiny action plan.';
}

function pickHabitTitle(lower) {
  if (lower.includes('water')) return 'Drink Water';
  if (lower.includes('read')) return 'Read 10 Minutes';
  if (lower.includes('walk')) return 'Take a 10-Minute Walk';
  if (lower.includes('sleep')) return 'Sleep on Time';
  return 'Daily Check-In';
}

function escapeJson(value) {
  return String(value).replaceAll('"', '\\"');
}

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Access-Control-Allow-Origin': '*',
    },
  });
}
