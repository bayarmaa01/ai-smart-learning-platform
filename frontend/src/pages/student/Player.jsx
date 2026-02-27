import React, { useState } from 'react';
import { useParams, Link } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import {
  Play, ChevronLeft, ChevronRight, Check, BookOpen,
  MessageSquare, FileText, Bot, ChevronDown, ChevronUp
} from 'lucide-react';

const mockLessons = [
  { id: '1', title: 'Welcome to the course', duration: '5:30', completed: true, section: 'Data Preprocessing' },
  { id: '2', title: 'Getting the Dataset', duration: '8:15', completed: true, section: 'Data Preprocessing' },
  { id: '3', title: 'Importing the Libraries', duration: '6:45', completed: false, section: 'Data Preprocessing' },
  { id: '4', title: 'Handling Missing Data', duration: '12:20', completed: false, section: 'Data Preprocessing' },
  { id: '5', title: 'Simple Linear Regression', duration: '15:00', completed: false, section: 'Regression' },
];

export default function PlayerPage() {
  const { t } = useTranslation();
  const { id } = useParams();
  const [currentLesson, setCurrentLesson] = useState(mockLessons[2]);
  const [activeTab, setActiveTab] = useState('curriculum');
  const [note, setNote] = useState('');

  const currentIndex = mockLessons.findIndex((l) => l.id === currentLesson.id);
  const progress = Math.round((mockLessons.filter((l) => l.completed).length / mockLessons.length) * 100);

  return (
    <div className="animate-fade-in -m-4 lg:-m-6">
      <div className="flex flex-col lg:flex-row h-[calc(100vh-64px)]">
        <div className="flex-1 flex flex-col min-w-0">
          <div className="bg-black aspect-video lg:aspect-auto lg:flex-1 flex items-center justify-center relative">
            <div className="text-center">
              <div className="w-20 h-20 bg-white/10 rounded-full flex items-center justify-center mx-auto mb-4 cursor-pointer hover:bg-white/20 transition-colors">
                <Play className="w-8 h-8 text-white ml-1" />
              </div>
              <p className="text-white/60 text-sm">{currentLesson.title}</p>
            </div>
            <div className="absolute bottom-4 left-4 right-4">
              <div className="bg-white/10 rounded-full h-1">
                <div className="bg-primary-500 h-1 rounded-full w-1/3" />
              </div>
            </div>
          </div>

          <div className="p-4 bg-slate-900 border-t border-slate-700">
            <div className="flex items-center justify-between mb-2">
              <h2 className="font-semibold text-white">{currentLesson.title}</h2>
              <button className="flex items-center gap-2 text-sm text-green-400 hover:text-green-300 transition-colors">
                <Check className="w-4 h-4" />
                {t('player.markComplete')}
              </button>
            </div>
            <div className="flex items-center gap-4">
              <button
                onClick={() => currentIndex > 0 && setCurrentLesson(mockLessons[currentIndex - 1])}
                disabled={currentIndex === 0}
                className="flex items-center gap-1 text-sm text-slate-400 hover:text-white disabled:opacity-40 transition-colors"
              >
                <ChevronLeft className="w-4 h-4" />
                {t('player.previousLesson')}
              </button>
              <div className="flex-1 bg-slate-700 rounded-full h-1.5">
                <div className="bg-primary-500 h-1.5 rounded-full transition-all" style={{ width: `${progress}%` }} />
              </div>
              <button
                onClick={() => currentIndex < mockLessons.length - 1 && setCurrentLesson(mockLessons[currentIndex + 1])}
                disabled={currentIndex === mockLessons.length - 1}
                className="flex items-center gap-1 text-sm text-slate-400 hover:text-white disabled:opacity-40 transition-colors"
              >
                {t('player.nextLesson')}
                <ChevronRight className="w-4 h-4" />
              </button>
            </div>
          </div>
        </div>

        <div className="w-full lg:w-80 bg-slate-900 border-l border-slate-700 flex flex-col">
          <div className="flex border-b border-slate-700">
            {[
              { id: 'curriculum', icon: BookOpen, label: t('player.curriculum') },
              { id: 'notes', icon: FileText, label: t('player.notes') },
              { id: 'ai', icon: Bot, label: 'AI' },
            ].map(({ id: tabId, icon: Icon, label }) => (
              <button
                key={tabId}
                onClick={() => setActiveTab(tabId)}
                className={`flex-1 flex items-center justify-center gap-1.5 py-3 text-xs font-medium transition-colors ${
                  activeTab === tabId
                    ? 'text-primary-400 border-b-2 border-primary-500'
                    : 'text-slate-400 hover:text-white'
                }`}
              >
                <Icon className="w-4 h-4" />
                {label}
              </button>
            ))}
          </div>

          <div className="flex-1 overflow-y-auto">
            {activeTab === 'curriculum' && (
              <div className="p-2">
                {mockLessons.map((lesson, i) => (
                  <button
                    key={lesson.id}
                    onClick={() => setCurrentLesson(lesson)}
                    className={`w-full flex items-start gap-3 p-3 rounded-xl mb-1 text-left transition-colors ${
                      currentLesson.id === lesson.id
                        ? 'bg-primary-600/20 border border-primary-500/30'
                        : 'hover:bg-slate-800/50'
                    }`}
                  >
                    <div className={`w-6 h-6 rounded-full flex items-center justify-center flex-shrink-0 mt-0.5 ${
                      lesson.completed ? 'bg-green-500' : 'bg-slate-700'
                    }`}>
                      {lesson.completed ? (
                        <Check className="w-3 h-3 text-white" />
                      ) : (
                        <span className="text-xs text-slate-400">{i + 1}</span>
                      )}
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className={`text-sm font-medium truncate ${
                        currentLesson.id === lesson.id ? 'text-primary-300' : 'text-slate-300'
                      }`}>
                        {lesson.title}
                      </p>
                      <p className="text-xs text-slate-500 mt-0.5">{lesson.duration}</p>
                    </div>
                  </button>
                ))}
              </div>
            )}

            {activeTab === 'notes' && (
              <div className="p-4">
                <textarea
                  value={note}
                  onChange={(e) => setNote(e.target.value)}
                  placeholder={t('player.addNote')}
                  className="input-field h-32 resize-none text-sm mb-3"
                />
                <button className="btn-primary w-full text-sm py-2">{t('player.saveNote')}</button>
              </div>
            )}

            {activeTab === 'ai' && (
              <div className="p-4 text-center">
                <Bot className="w-10 h-10 text-primary-400 mx-auto mb-3" />
                <p className="text-sm text-slate-400 mb-4">{t('player.askAI')}</p>
                <Link to="/ai-chat" className="btn-primary w-full text-sm py-2 flex items-center justify-center gap-2">
                  <Bot className="w-4 h-4" />
                  Open AI Chat
                </Link>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
