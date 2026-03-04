import React, { useState, useEffect } from 'react';
import { useTranslation } from 'react-i18next';
import { useNavigate } from 'react-router-dom';
import { CheckCircle, Clock, ChevronRight, Award } from 'lucide-react';
import api from '../../services/api';

const questions = [
  {
    id: 1, category: 'Programming',
    question: 'What is the time complexity of binary search?',
    options: ['O(n)', 'O(log n)', 'O(n²)', 'O(1)'],
    correct: 1,
  },
  {
    id: 2, category: 'Data Science',
    question: 'Which algorithm is used for classification problems?',
    options: ['Linear Regression', 'K-Means', 'Logistic Regression', 'PCA'],
    correct: 2,
  },
  {
    id: 3, category: 'Web Dev',
    question: 'What does REST stand for?',
    options: ['Remote State Transfer', 'Representational State Transfer', 'Request State Transfer', 'Resource State Transfer'],
    correct: 1,
  },
  {
    id: 4, category: 'DevOps',
    question: 'What is Docker used for?',
    options: ['Database management', 'Container orchestration', 'Application containerization', 'Load balancing'],
    correct: 2,
  },
  {
    id: 5, category: 'Cloud',
    question: 'Which AWS service is used for serverless computing?',
    options: ['EC2', 'S3', 'Lambda', 'RDS'],
    correct: 2,
  },
];

export default function PlacementTestPage() {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const [phase, setPhase] = useState('intro');
  const [current, setCurrent] = useState(0);
  const [answers, setAnswers] = useState({});
  const [timeLeft, setTimeLeft] = useState(300);
  const [result, setResult] = useState(null);

  useEffect(() => {
    if (phase !== 'test') return;
    const timer = setInterval(() => {
      setTimeLeft((t) => {
        if (t <= 1) { clearInterval(timer); handleSubmit(); return 0; }
        return t - 1;
      });
    }, 1000);
    return () => clearInterval(timer);
  }, [phase]);

  const handleAnswer = (questionId, optionIndex) => {
    setAnswers({ ...answers, [questionId]: optionIndex });
  };

  const handleSubmit = async () => {
    const score = questions.reduce((acc, q) => acc + (answers[q.id] === q.correct ? 1 : 0), 0);
    const pct = (score / questions.length) * 100;
    const level = pct >= 80 ? 'advanced' : pct >= 50 ? 'intermediate' : 'beginner';
    const resultData = { score, total: questions.length, pct, level };
    setResult(resultData);
    setPhase('result');

    // Save placement result to backend (non-blocking)
    api.post('/users/placement-result', {
      level,
      score,
      total: questions.length,
      percentage: pct,
      answers: Object.entries(answers).map(([qId, optIdx]) => ({ questionId: qId, selectedOption: optIdx })),
    }).catch(() => null);
  };

  const formatTime = (s) => `${Math.floor(s / 60)}:${(s % 60).toString().padStart(2, '0')}`;

  if (phase === 'intro') {
    return (
      <div className="max-w-2xl mx-auto animate-slide-up">
        <div className="card text-center">
          <div className="w-16 h-16 bg-primary-600/20 rounded-2xl flex items-center justify-center mx-auto mb-6">
            <Award className="w-8 h-8 text-primary-400" />
          </div>
          <h1 className="text-2xl font-bold text-white mb-3">{t('placement.title')}</h1>
          <p className="text-slate-400 mb-8">{t('placement.subtitle')}</p>
          <div className="grid grid-cols-3 gap-4 mb-8">
            {[
              { label: 'Questions', value: questions.length },
              { label: 'Time Limit', value: '5 min' },
              { label: 'Categories', value: '5' },
            ].map(({ label, value }) => (
              <div key={label} className="p-4 bg-slate-800/50 rounded-xl">
                <p className="text-2xl font-bold text-white">{value}</p>
                <p className="text-sm text-slate-400">{label}</p>
              </div>
            ))}
          </div>
          <button onClick={() => setPhase('test')} className="btn-primary px-8 py-3 text-base">
            {t('placement.start')}
          </button>
        </div>
      </div>
    );
  }

  if (phase === 'test') {
    const q = questions[current];
    return (
      <div className="max-w-2xl mx-auto animate-slide-up">
        <div className="flex items-center justify-between mb-6">
          <span className="text-slate-400 text-sm">
            {t('placement.question', { current: current + 1, total: questions.length })}
          </span>
          <div className="flex items-center gap-2 text-slate-400">
            <Clock className="w-4 h-4" />
            <span className={`font-mono font-semibold ${timeLeft < 60 ? 'text-red-400' : 'text-white'}`}>
              {formatTime(timeLeft)}
            </span>
          </div>
        </div>

        <div className="w-full bg-slate-700 rounded-full h-2 mb-6">
          <div className="bg-primary-500 h-2 rounded-full transition-all" style={{ width: `${((current + 1) / questions.length) * 100}%` }} />
        </div>

        <div className="card">
          <span className="badge-purple mb-4 inline-block">{q.category}</span>
          <h2 className="text-lg font-semibold text-white mb-6">{q.question}</h2>
          <div className="space-y-3">
            {q.options.map((option, i) => (
              <button
                key={i}
                onClick={() => handleAnswer(q.id, i)}
                className={`w-full text-left p-4 rounded-xl border transition-all duration-200 ${
                  answers[q.id] === i
                    ? 'border-primary-500 bg-primary-600/20 text-white'
                    : 'border-slate-700 hover:border-slate-500 text-slate-300 hover:bg-slate-800/50'
                }`}
              >
                <div className="flex items-center gap-3">
                  <div className={`w-6 h-6 rounded-full border-2 flex items-center justify-center flex-shrink-0 ${
                    answers[q.id] === i ? 'border-primary-500 bg-primary-500' : 'border-slate-600'
                  }`}>
                    {answers[q.id] === i && <div className="w-2 h-2 bg-white rounded-full" />}
                  </div>
                  <span className="text-sm">{option}</span>
                </div>
              </button>
            ))}
          </div>

          <div className="flex justify-between mt-6">
            <button
              onClick={() => setCurrent(Math.max(0, current - 1))}
              disabled={current === 0}
              className="btn-secondary disabled:opacity-40"
            >
              {t('common.previous')}
            </button>
            {current < questions.length - 1 ? (
              <button
                onClick={() => setCurrent(current + 1)}
                className="btn-primary flex items-center gap-2"
              >
                {t('common.next')} <ChevronRight className="w-4 h-4" />
              </button>
            ) : (
              <button onClick={handleSubmit} className="btn-primary">{t('placement.submit')}</button>
            )}
          </div>
        </div>
      </div>
    );
  }

  if (phase === 'result' && result) {
    const levelColors = { beginner: 'text-green-400', intermediate: 'text-yellow-400', advanced: 'text-purple-400' };
    return (
      <div className="max-w-2xl mx-auto animate-slide-up">
        <div className="card text-center">
          <CheckCircle className="w-16 h-16 text-green-400 mx-auto mb-4" />
          <h1 className="text-2xl font-bold text-white mb-2">{t('placement.result')}</h1>
          <p className="text-slate-400 mb-8">Based on your answers, we recommend:</p>

          <div className="p-6 bg-slate-800/50 rounded-2xl mb-8">
            <p className={`text-4xl font-bold mb-2 ${levelColors[result.level]}`}>
              {t(`placement.${result.level}`)}
            </p>
            <p className="text-slate-400">
              {result.score}/{result.total} correct ({Math.round(result.pct)}%)
            </p>
          </div>

          <div className="flex gap-4">
            <button onClick={() => { setPhase('intro'); setAnswers({}); setCurrent(0); setTimeLeft(300); }}
              className="btn-secondary flex-1">
              {t('placement.retake')}
            </button>
            <button onClick={() => navigate('/courses')} className="btn-primary flex-1">
              {t('placement.proceed')}
            </button>
          </div>
        </div>
      </div>
    );
  }

  return null;
}
