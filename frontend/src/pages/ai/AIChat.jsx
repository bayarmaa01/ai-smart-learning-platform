import React, { useState, useRef, useEffect } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { useTranslation } from 'react-i18next';
import { sendMessage, addUserMessage, clearChat } from '../../store/slices/chatSlice';
import ReactMarkdown from 'react-markdown';
import { Bot, User, Send, Trash2, Copy, Check, Loader2, Sparkles } from 'lucide-react';
import toast from 'react-hot-toast';

const uuidv4 = () => crypto.randomUUID();

const SUGGESTIONS_EN = [
  'Explain machine learning in simple terms',
  'What is the difference between AI and ML?',
  'How do neural networks work?',
  'Recommend courses for a Python beginner',
];

const SUGGESTIONS_MN = [
  'Машин сургалтыг энгийнээр тайлбарла',
  'AI болон ML-ийн ялгаа юу вэ?',
  'Нейрон сүлжээ хэрхэн ажилладаг вэ?',
  'Python анхлан суралцагчид ямар хичээл санал болгох вэ?',
];

function MessageBubble({ message }) {
  const [copied, setCopied] = useState(false);
  const isUser = message.role === 'user';

  const handleCopy = () => {
    navigator.clipboard.writeText(message.content);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <div className={`flex gap-3 ${isUser ? 'flex-row-reverse' : ''} group animate-slide-up`}>
      <div className={`w-8 h-8 rounded-full flex items-center justify-center flex-shrink-0 ${
        isUser ? 'bg-primary-600' : 'bg-gradient-to-br from-purple-600 to-primary-600'
      }`}>
        {isUser ? <User className="w-4 h-4 text-white" /> : <Bot className="w-4 h-4 text-white" />}
      </div>

      <div className={`max-w-[75%] ${isUser ? 'items-end' : 'items-start'} flex flex-col gap-1`}>
        <div className={`px-4 py-3 rounded-2xl text-sm leading-relaxed ${
          isUser
            ? 'bg-primary-600 text-white rounded-tr-sm'
            : message.isError
            ? 'bg-red-500/10 border border-red-500/20 text-red-300 rounded-tl-sm'
            : 'bg-slate-800 text-slate-200 rounded-tl-sm border border-slate-700'
        }`}>
          {isUser ? (
            <p>{message.content}</p>
          ) : (
            <ReactMarkdown
              components={{
                p: ({ children }) => <p className="mb-2 last:mb-0">{children}</p>,
                code: ({ children }) => (
                  <code className="bg-slate-900 px-1.5 py-0.5 rounded text-xs font-mono text-primary-300">{children}</code>
                ),
                pre: ({ children }) => (
                  <pre className="bg-slate-900 p-3 rounded-lg text-xs font-mono overflow-x-auto my-2">{children}</pre>
                ),
                ul: ({ children }) => <ul className="list-disc list-inside space-y-1 my-2">{children}</ul>,
                ol: ({ children }) => <ol className="list-decimal list-inside space-y-1 my-2">{children}</ol>,
                strong: ({ children }) => <strong className="font-semibold text-white">{children}</strong>,
              }}
            >
              {message.content}
            </ReactMarkdown>
          )}
        </div>

        <div className={`flex items-center gap-2 opacity-0 group-hover:opacity-100 transition-opacity ${isUser ? 'flex-row-reverse' : ''}`}>
          <span className="text-xs text-slate-500">
            {new Date(message.timestamp).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
          </span>
          {!isUser && (
            <button onClick={handleCopy} className="text-xs text-slate-500 hover:text-slate-300 flex items-center gap-1 transition-colors">
              {copied ? <Check className="w-3 h-3 text-green-400" /> : <Copy className="w-3 h-3" />}
              {copied ? 'Copied!' : 'Copy'}
            </button>
          )}
          {message.detectedLanguage && (
            <span className="text-xs text-slate-600 italic">
              Detected: {message.detectedLanguage === 'mn' ? 'Mongolian' : 'English'}
            </span>
          )}
        </div>
      </div>
    </div>
  );
}

export default function AIChatPage() {
  const { t, i18n } = useTranslation();
  const dispatch = useDispatch();
  const { messages, isTyping, sessionId } = useSelector((state) => state.chat);
  const [input, setInput] = useState('');
  const [currentSessionId] = useState(() => uuidv4());
  const messagesEndRef = useRef(null);
  const inputRef = useRef(null);

  const lang = i18n.language?.startsWith('mn') ? 'mn' : 'en';
  const suggestions = lang === 'mn' ? SUGGESTIONS_MN : SUGGESTIONS_EN;

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages, isTyping]);

  const handleSend = async () => {
    const trimmed = input.trim();
    if (!trimmed || isTyping) return;

    dispatch(addUserMessage({ content: trimmed }));
    setInput('');

    await dispatch(sendMessage({ message: trimmed, sessionId: sessionId || currentSessionId }));
  };

  const handleKeyDown = (e) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSend();
    }
  };

  const handleSuggestion = (suggestion) => {
    setInput(suggestion);
    inputRef.current?.focus();
  };

  return (
    <div className="flex flex-col h-[calc(100vh-130px)] animate-fade-in">
      <div className="flex items-center justify-between mb-4">
        <div>
          <h1 className="text-2xl font-bold text-white flex items-center gap-2">
            <Sparkles className="w-6 h-6 text-primary-400" />
            {t('ai.title')}
          </h1>
          <p className="text-slate-400 text-sm mt-1">{t('ai.subtitle')}</p>
        </div>
        {messages.length > 0 && (
          <button
            onClick={() => dispatch(clearChat())}
            className="flex items-center gap-2 text-sm text-slate-400 hover:text-red-400 transition-colors"
          >
            <Trash2 className="w-4 h-4" />
            {t('ai.clearChat')}
          </button>
        )}
      </div>

      <div className="flex-1 overflow-y-auto space-y-4 p-4 bg-slate-900/50 rounded-2xl border border-slate-700/50 mb-4">
        {messages.length === 0 ? (
          <div className="h-full flex flex-col items-center justify-center text-center">
            <div className="w-16 h-16 bg-gradient-to-br from-primary-600 to-accent-600 rounded-2xl flex items-center justify-center mb-4">
              <Bot className="w-8 h-8 text-white" />
            </div>
            <p className="text-white font-semibold mb-2">{t('ai.greeting')}</p>
            <p className="text-slate-400 text-sm mb-8 max-w-md">{t('ai.startConversation')}</p>

            <div className="w-full max-w-lg">
              <p className="text-xs text-slate-500 mb-3 uppercase tracking-wider">{t('ai.suggestions')}</p>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
                {suggestions.map((s) => (
                  <button
                    key={s}
                    onClick={() => handleSuggestion(s)}
                    className="text-left p-3 bg-slate-800 hover:bg-slate-700 border border-slate-700 hover:border-slate-600 rounded-xl text-sm text-slate-300 hover:text-white transition-all duration-200"
                  >
                    {s}
                  </button>
                ))}
              </div>
            </div>
          </div>
        ) : (
          <>
            {messages.map((msg) => (
              <MessageBubble key={msg.id} message={msg} />
            ))}
            {isTyping && (
              <div className="flex gap-3 animate-slide-up">
                <div className="w-8 h-8 rounded-full bg-gradient-to-br from-purple-600 to-primary-600 flex items-center justify-center flex-shrink-0">
                  <Bot className="w-4 h-4 text-white" />
                </div>
                <div className="bg-slate-800 border border-slate-700 px-4 py-3 rounded-2xl rounded-tl-sm">
                  <div className="flex gap-1.5 items-center h-5">
                    {[0, 1, 2].map((i) => (
                      <div
                        key={i}
                        className="w-2 h-2 bg-slate-400 rounded-full animate-bounce"
                        style={{ animationDelay: `${i * 0.15}s` }}
                      />
                    ))}
                  </div>
                </div>
              </div>
            )}
            <div ref={messagesEndRef} />
          </>
        )}
      </div>

      <div className="flex gap-3">
        <div className="flex-1 relative">
          <textarea
            ref={inputRef}
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onKeyDown={handleKeyDown}
            placeholder={t('ai.placeholder')}
            rows={1}
            className="input-field resize-none pr-12 py-3 text-sm leading-relaxed"
            style={{ minHeight: '48px', maxHeight: '120px' }}
          />
        </div>
        <button
          onClick={handleSend}
          disabled={!input.trim() || isTyping}
          className="w-12 h-12 bg-primary-600 hover:bg-primary-700 disabled:opacity-50 disabled:cursor-not-allowed text-white rounded-xl flex items-center justify-center transition-all duration-200 flex-shrink-0"
        >
          {isTyping ? <Loader2 className="w-5 h-5 animate-spin" /> : <Send className="w-5 h-5" />}
        </button>
      </div>
      <p className="text-xs text-slate-500 text-center mt-2">
        Press Enter to send • Shift+Enter for new line • Supports English & Mongolian
      </p>
    </div>
  );
}
