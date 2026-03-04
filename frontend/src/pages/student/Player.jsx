import React, { useState, useEffect, useCallback } from 'react';
import { useParams, Link } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { useSelector } from 'react-redux';
import api from '../../services/api';
import {
  Play, ChevronLeft, ChevronRight, Check, BookOpen,
  MessageSquare, FileText, Bot, Loader2, AlertCircle
} from 'lucide-react';
import toast from 'react-hot-toast';

export default function PlayerPage() {
  const { t } = useTranslation();
  const { id } = useParams();
  const { user } = useSelector((state) => state.auth);

  const [lessons, setLessons] = useState([]);
  const [currentLesson, setCurrentLesson] = useState(null);
  const [activeTab, setActiveTab] = useState('curriculum');
  const [note, setNote] = useState('');
  const [savingNote, setSavingNote] = useState(false);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [markingComplete, setMarkingComplete] = useState(false);

  const fetchLessons = useCallback(async () => {
    try {
      setLoading(true);
      const res = await api.get(`/courses/${id}`);
      const course = res.data.course;
      const allLessons = (course.sections || course.curriculum || []).flatMap((s) =>
        (s.lessons || []).map((l) => ({ ...l, section: s.title }))
      );
      setLessons(allLessons);

      const progressRes = await api.get(`/courses/${id}/progress`).catch(() => ({ data: { progress: [] } }));
      const completedIds = new Set((progressRes.data.progress || []).filter((p) => p.completed_at).map((p) => p.lesson_id));

      const enriched = allLessons.map((l) => ({ ...l, completed: completedIds.has(l.id) }));
      setLessons(enriched);

      const firstIncomplete = enriched.find((l) => !l.completed) || enriched[0];
      setCurrentLesson(firstIncomplete || null);
    } catch (err) {
      setError('Failed to load course content');
    } finally {
      setLoading(false);
    }
  }, [id]);

  useEffect(() => {
    fetchLessons();
  }, [fetchLessons]);

  const handleMarkComplete = async () => {
    if (!currentLesson || markingComplete) return;
    setMarkingComplete(true);
    try {
      await api.post(`/courses/${id}/progress`, {
        lessonId: currentLesson.id,
        completed: true,
        watchedSeconds: currentLesson.duration_seconds || 0,
      });
      setLessons((prev) =>
        prev.map((l) => l.id === currentLesson.id ? { ...l, completed: true } : l)
      );
      setCurrentLesson((prev) => ({ ...prev, completed: true }));
      toast.success(t('player.markedComplete', { defaultValue: 'Lesson marked as complete!' }));

      const currentIndex = lessons.findIndex((l) => l.id === currentLesson.id);
      if (currentIndex < lessons.length - 1) {
        setTimeout(() => setCurrentLesson(lessons[currentIndex + 1]), 500);
      }
    } catch {
      toast.error('Failed to mark lesson complete');
    } finally {
      setMarkingComplete(false);
    }
  };

  const handleSaveNote = async () => {
    if (!note.trim() || !currentLesson) return;
    setSavingNote(true);
    try {
      await api.post(`/courses/${id}/notes`, {
        lessonId: currentLesson.id,
        content: note.trim(),
      }).catch(() => null);
      toast.success(t('player.noteSaved', { defaultValue: 'Note saved!' }));
      setNote('');
    } catch {
      toast.error('Failed to save note');
    } finally {
      setSavingNote(false);
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-[calc(100vh-64px)]">
        <Loader2 className="w-10 h-10 text-primary-400 animate-spin" />
      </div>
    );
  }

  if (error || !currentLesson) {
    return (
      <div className="flex flex-col items-center justify-center h-[calc(100vh-64px)] text-center">
        <AlertCircle className="w-12 h-12 text-red-400 mb-4" />
        <p className="text-white text-lg mb-2">{error || 'No lessons found'}</p>
        <Link to={`/courses/${id}`} className="btn-secondary mt-4">Back to Course</Link>
      </div>
    );
  }

  const currentIndex = lessons.findIndex((l) => l.id === currentLesson.id);
  const completedCount = lessons.filter((l) => l.completed).length;
  const progress = lessons.length > 0 ? Math.round((completedCount / lessons.length) * 100) : 0;

  return (
    <div className="animate-fade-in -m-4 lg:-m-6">
      <div className="flex flex-col lg:flex-row h-[calc(100vh-64px)]">
        <div className="flex-1 flex flex-col min-w-0">
          <div className="bg-black aspect-video lg:aspect-auto lg:flex-1 flex items-center justify-center relative">
            {currentLesson.video_url ? (
              <video
                key={currentLesson.id}
                controls
                className="w-full h-full"
                src={currentLesson.video_url}
                onEnded={handleMarkComplete}
              >
                Your browser does not support video playback.
              </video>
            ) : (
              <div className="text-center">
                <div className="w-20 h-20 bg-white/10 rounded-full flex items-center justify-center mx-auto mb-4">
                  <Play className="w-8 h-8 text-white ml-1" />
                </div>
                <p className="text-white/60 text-sm">{currentLesson.title}</p>
                <p className="text-white/30 text-xs mt-2">No video URL configured for this lesson</p>
              </div>
            )}
            <div className="absolute bottom-4 left-4 right-4">
              <div className="bg-white/10 rounded-full h-1">
                <div className="bg-primary-500 h-1 rounded-full transition-all" style={{ width: `${progress}%` }} />
              </div>
            </div>
          </div>

          <div className="p-4 bg-slate-900 border-t border-slate-700">
            <div className="flex items-center justify-between mb-2">
              <div>
                <h2 className="font-semibold text-white">{currentLesson.title}</h2>
                {currentLesson.section && (
                  <p className="text-xs text-slate-400 mt-0.5">{currentLesson.section}</p>
                )}
              </div>
              <button
                onClick={handleMarkComplete}
                disabled={currentLesson.completed || markingComplete}
                className={`flex items-center gap-2 text-sm transition-colors ${
                  currentLesson.completed
                    ? 'text-green-400 cursor-default'
                    : 'text-slate-400 hover:text-green-400'
                }`}
              >
                {markingComplete
                  ? <Loader2 className="w-4 h-4 animate-spin" />
                  : <Check className="w-4 h-4" />}
                {currentLesson.completed ? 'Completed' : t('player.markComplete')}
              </button>
            </div>
            <div className="flex items-center gap-4">
              <button
                onClick={() => currentIndex > 0 && setCurrentLesson(lessons[currentIndex - 1])}
                disabled={currentIndex === 0}
                className="flex items-center gap-1 text-sm text-slate-400 hover:text-white disabled:opacity-40 transition-colors"
              >
                <ChevronLeft className="w-4 h-4" />
                {t('player.previousLesson')}
              </button>
              <div className="flex-1 bg-slate-700 rounded-full h-1.5">
                <div className="bg-primary-500 h-1.5 rounded-full transition-all" style={{ width: `${progress}%` }} />
              </div>
              <span className="text-xs text-slate-400 flex-shrink-0">{progress}%</span>
              <button
                onClick={() => currentIndex < lessons.length - 1 && setCurrentLesson(lessons[currentIndex + 1])}
                disabled={currentIndex === lessons.length - 1}
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
                {lessons.map((lesson, i) => (
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
                      {lesson.completed
                        ? <Check className="w-3 h-3 text-white" />
                        : <span className="text-xs text-slate-400">{i + 1}</span>}
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className={`text-sm font-medium truncate ${
                        currentLesson.id === lesson.id ? 'text-primary-300' : 'text-slate-300'
                      }`}>
                        {lesson.title}
                      </p>
                      {lesson.section && (
                        <p className="text-xs text-slate-500 mt-0.5 truncate">{lesson.section}</p>
                      )}
                    </div>
                  </button>
                ))}
              </div>
            )}

            {activeTab === 'notes' && (
              <div className="p-4">
                <p className="text-xs text-slate-400 mb-3">
                  Notes for: <span className="text-white">{currentLesson.title}</span>
                </p>
                <textarea
                  value={note}
                  onChange={(e) => setNote(e.target.value)}
                  placeholder={t('player.addNote')}
                  className="input-field h-32 resize-none text-sm mb-3"
                />
                <button
                  onClick={handleSaveNote}
                  disabled={savingNote || !note.trim()}
                  className="btn-primary w-full text-sm py-2 flex items-center justify-center gap-2"
                >
                  {savingNote ? <Loader2 className="w-3 h-3 animate-spin" /> : null}
                  {t('player.saveNote')}
                </button>
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
