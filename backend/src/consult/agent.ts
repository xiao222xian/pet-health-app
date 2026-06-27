import {
  CONSULT_DISCLAIMER,
  ConsultEvent,
  ConsultInput,
  createSessionId,
  createTraceId,
  buildBaseResponse,
} from './contract.js';
import { classifyIntent } from './intentClassifier.js';
import { attachLegacyFields, buildFallbackTriage, generateTriage } from './llm.js';
import { detectEmergency } from './riskRules.js';
import { getConsultStateStore } from './stateStore.js';
import { ConsultAgentResponse } from '../types/index.js';

const SESSION_TTL_SECONDS = 60 * 60 * 24;

type Emit = (event: ConsultEvent) => void | Promise<void>;

export async function runConsultAgent(input: ConsultInput, userId: string, emit?: Emit): Promise<ConsultAgentResponse> {
  const sessionId = input.sessionId ?? createSessionId();
  const traceId = createTraceId();
  const store = getConsultStateStore();

  const send = async (event: ConsultEvent) => {
    await store.appendEvent(sessionId, { ...event, at: new Date().toISOString() }, SESSION_TTL_SECONDS);
    await emit?.(event);
  };

  const transition = async (state: string, extra: Record<string, unknown> = {}) => {
    await store.setSession({
      session_id: sessionId,
      pet_id: input.pet.id,
      user_id: userId,
      state,
      updated_at: new Date().toISOString(),
      trace_id: traceId,
      ...extra,
    }, SESSION_TTL_SECONDS);
    await send({ event: 'state', data: { state, ...extra } });
  };

  await send({ event: 'trace', data: { trace_id: traceId, session_id: sessionId, state_store: store.mode } });
  await transition('LOAD_CONTEXT');

  const symptoms = input.symptoms.trim();
  const hasPhoto = input.photoData.length > 0 || input.photoUrls.length > 0;

  await transition('SCAN_RISK_RULES');
  const emergency = detectEmergency(symptoms);
  if (emergency) {
    const response = buildBaseResponse({
      responseType: 'emergency_alert',
      intent: 'symptom_triage',
      canAssess: true,
      riskLevel: emergency.riskLevel,
      title: emergency.title,
      shortAnswer: emergency.shortAnswer,
      summary: emergency.shortAnswer,
      nextActions: emergency.nextActions,
      sessionId,
      traceId,
      state: 'EMERGENCY_ALERT',
    });
    response.emergency = emergency.emergency;
    response.when_to_seek_vet = emergency.emergency.immediate_actions;
    response.advice = emergency.emergency.immediate_actions;
    response.seek_vet = true;
    await transition('COMPLETE', { last_response_type: response.response_type, last_risk_level: response.risk_level });
    await send({ event: 'result', data: response as unknown as Record<string, unknown> });
    return response;
  }

  await transition('CLASSIFY_INTENT');
  const decision = classifyIntent(symptoms, hasPhoto);
  if (!decision.canAssess || decision.responseType !== 'triage_report') {
    const response = buildBaseResponse({
      responseType: decision.responseType,
      intent: decision.intent,
      canAssess: decision.canAssess,
      title: decision.responseType === 'guide' ? '先补充症状信息' : '还需要更多信息',
      shortAnswer: decision.reason,
      missingInfo: decision.missingInfo,
      followUpQuestions: decision.followUpQuestions,
      nextActions: decision.nextActions,
      sessionId,
      traceId,
      state: decision.responseType === 'guide' ? 'ASK_GUIDE' : 'ASK_FOLLOWUP',
    });
    await transition('COMPLETE', { last_response_type: response.response_type, last_risk_level: response.risk_level });
    await send({ event: 'result', data: response as unknown as Record<string, unknown> });
    return response;
  }

  await transition('GENERATE_TRIAGE');
  await send({ event: 'token', data: { text: '正在结合宠物资料和症状做风险分层...' } });
  let generated: Awaited<ReturnType<typeof generateTriage>>;
  try {
    generated = await generateTriage({
      pet: input.pet,
      symptoms,
      photoData: input.photoData,
    });
  } catch (error) {
    const reason = error instanceof Error ? error.message : String(error);
    console.warn('consult llm failed, using fallback triage', reason);
    await send({ event: 'token', data: { text: '模型服务不稳定，正在切换保守分诊方案...' } });
    generated = buildFallbackTriage({ symptoms, reason });
  }

  await transition('VALIDATE_RESPONSE');
  const questions = [
    ...decision.followUpQuestions,
    ...(generated.follow_up_question
      ? [{ id: 'model_follow_up', text: generated.follow_up_question, reason: '模型认为这个信息能提高下一轮判断质量。' }]
      : []),
  ].slice(0, 2);

  const response = attachLegacyFields({
    response_type: 'triage_report',
    intent: decision.intent,
    can_assess: true,
    risk_level: generated.risk_level,
    title: generated.title,
    short_answer: generated.short_answer,
    summary: generated.summary,
    possible_causes: generated.triage.possible_causes,
    home_care: generated.triage.home_care,
    watch_points: generated.triage.watch_points,
    when_to_seek_vet: generated.triage.when_to_seek_vet,
    follow_up_question: questions[0]?.text ?? '',
    missing_info: decision.missingInfo,
    follow_up_questions: questions,
    next_actions: buildNextActions(generated),
    triage: generated.triage,
    advice: generated.triage.home_care,
    seek_vet: generated.seek_vet,
    disclaimer: CONSULT_DISCLAIMER,
    session_id: sessionId,
    trace_id: traceId,
    provider: generated.provider,
    model: generated.model,
    state: 'COMPLETE',
  });

  await transition('COMPLETE', { last_response_type: response.response_type, last_risk_level: response.risk_level });
  await send({ event: 'result', data: response as unknown as Record<string, unknown> });
  return response;
}

function buildNextActions(generated: Awaited<ReturnType<typeof generateTriage>>): ConsultAgentResponse['next_actions'] {
  if (generated.risk_level === 'emergency') {
    return [{ priority: 'now', text: '立即前往宠物急诊或联系附近宠物医院。' }];
  }
  if (generated.risk_level === 'high') {
    return [{ priority: 'today', text: '建议今天尽快预约或前往宠物医院检查。' }];
  }
  if (generated.risk_level === 'medium') {
    return [{ priority: 'monitor', text: '接下来 6-12 小时重点观察精神、食欲、饮水、排便排尿和症状频次。' }];
  }
  return [{ priority: 'monitor', text: '先按建议居家观察；如果症状加重或持续超过 24 小时，建议就医。' }];
}
