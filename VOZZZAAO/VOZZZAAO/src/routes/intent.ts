import crypto from 'node:crypto';

import { Router } from 'express';
import { z } from 'zod';

const inputSchema = z.object({
  texto: z.string().min(1).max(500),
  contexto: z
    .object({
      ultimaAcao: z.string().optional(),
      ultimoAlvo: z.string().optional(),
    })
    .optional(),
});

const outputSchema = z.object({
  acao: z.enum([
    'ABRIR_WHATSAPP_CONTATO',
    'ENVIAR_WHATSAPP',
    'LIGAR_PARA',
    'ENVIAR_SMS',
    'ABRIR_APP',
    'TOCAR_MUSICA',
    'PESQUISAR_GOOGLE',
    'NAVEGAR_ATE',
    'DEFINIR_ALARME',
    'DEFINIR_LEMBRETE',
    'ENVIAR_EMAIL',
    'LER_NOTIFICACOES',
    'DESCONHECIDO',
  ]),
  alvo: z.string().nullable(),
  parametros: z.object({
    mensagem: z.string().nullable(),
    horario: z.string().nullable(),
    local: z.string().nullable(),
    query: z.string().nullable(),
  }),
  confianca: z.enum(['alta', 'media', 'baixa']),
  ambiguo: z.boolean(),
  perguntaConfirmacao: z.string().nullable(),
});

const injectionPattern = /(ignore previous|you are|você é|system prompt)/i;
const cache = new Map<string, { expiresAt: number; value: z.infer<typeof outputSchema> }>();
const ttlMs = 24 * 60 * 60 * 1000;

function normalize(texto: string): string {
  return texto.trim().toLowerCase();
}

function cacheKey(texto: string): string {
  return crypto.createHash('sha256').update(normalize(texto)).digest('hex');
}

function parseResponse(text: string): unknown {
  try {
    return JSON.parse(text);
  } catch {
    const start = text.indexOf('{');
    const end = text.lastIndexOf('}');
    if (start >= 0 && end > start) {
      return JSON.parse(text.slice(start, end + 1));
    }
    throw new Error('Resposta inválida da IA');
  }
}

function fallbackFromRules(texto: string): z.infer<typeof outputSchema> {
  const t = normalize(texto);
  if (t.startsWith('abrir whatsapp conversa com ')) {
    return {
      acao: 'ABRIR_WHATSAPP_CONTATO',
      alvo: t.replace('abrir whatsapp conversa com ', ''),
      parametros: { mensagem: null, horario: null, local: null, query: null },
      confianca: 'alta',
      ambiguo: false,
      perguntaConfirmacao: null,
    };
  }
  return {
    acao: 'DESCONHECIDO',
    alvo: null,
    parametros: { mensagem: null, horario: null, local: null, query: null },
    confianca: 'baixa',
    ambiguo: false,
    perguntaConfirmacao: null,
  };
}

async function callModel(texto: string): Promise<string> {
  // Placeholder para integração real Gemini/OpenAI (thinkingBudget=0 no provider suportado).
  return JSON.stringify(fallbackFromRules(texto));
}

export const intentRouter = Router();

intentRouter.post('/api/intent', async (req, res, next) => {
  const start = Date.now();

  try {
    const input = inputSchema.parse(req.body);
    if (injectionPattern.test(input.texto)) {
      return res.status(400).json({ error: 'texto_bloqueado' });
    }

    const key = cacheKey(input.texto);
    const hit = cache.get(key);
    if (hit && hit.expiresAt > Date.now()) {
      req.log?.info({ texto: input.texto, acao: hit.value.acao, latencyMs: Date.now() - start }, 'intent.cache.hit');
      return res.json(hit.value);
    }

    const raw = await callModel(input.texto);
    const parsed = parseResponse(raw);
    const output = outputSchema.parse(parsed);

    cache.set(key, { expiresAt: Date.now() + ttlMs, value: output });

    req.log?.info({ texto: input.texto, acao: output.acao, latencyMs: Date.now() - start }, 'intent.ok');
    return res.json(output);
  } catch (error) {
    next(error);
  }
});
