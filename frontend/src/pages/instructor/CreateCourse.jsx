import React, { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useNavigate } from 'react-router-dom';
import {
  Plus,
  Trash2,
  Save,
  Eye,
  Upload,
  FileText,
  Video,
  Image,
  X
} from 'lucide-react';
import toast from 'react-hot-toast';

export default function CreateCourse() {
  const { t } = useTranslation();
  const navigate = useNavigate();

  const [formData, setFormData] = useState({
    title: '',
    description: '',
    category: '',
    level: 'beginner',
    price: '',
    thumbnail: null,
    previewVideo: null,
    language: 'en',
    requirements: [''],
    objectives: [''],
    modules: [
      {
        title: '',
        lessons: [
          {
            title: '',
            type: 'video',
            content: '',
            duration: ''
          }
        ]
      }
    ]
  });

  const [isSaving, setIsSaving] = useState(false);
  const [previewMode, setPreviewMode] = useState(false);

  const handleInputChange = (field, value) => {
    setFormData(prev => ({
      ...prev,
      [field]: value
    }));
  };

  const addRequirement = () => {
    setFormData(prev => ({
      ...prev,
      requirements: [...prev.requirements, '']
    }));
  };

  const removeRequirement = (index) => {
    setFormData(prev => ({
      ...prev,
      requirements: prev.requirements.filter((_, i) => i !== index)
    }));
  };

  const updateRequirement = (index, value) => {
    setFormData(prev => ({
      ...prev,
      requirements: prev.requirements.map((req, i) => i === index ? value : req)
    }));
  };

  const addObjective = () => {
    setFormData(prev => ({
      ...prev,
      objectives: [...prev.objectives, '']
    }));
  };

  const removeObjective = (index) => {
    setFormData(prev => ({
      ...prev,
      objectives: prev.objectives.filter((_, i) => i !== index)
    }));
  };

  const updateObjective = (index, value) => {
    setFormData(prev => ({
      ...prev,
      objectives: prev.objectives.map((obj, i) => i === index ? value : obj)
    }));
  };

  const addModule = () => {
    setFormData(prev => ({
      ...prev,
      modules: [...prev.modules, {
        title: '',
        lessons: [
          {
            title: '',
            type: 'video',
            content: '',
            duration: ''
          }
        ]
      }]
    }));
  };

  const removeModule = (moduleIndex) => {
    setFormData(prev => ({
      ...prev,
      modules: prev.modules.filter((_, i) => i !== moduleIndex)
    }));
  };

  const updateModule = (moduleIndex, field, value) => {
    setFormData(prev => ({
      ...prev,
      modules: prev.modules.map((module, i) => 
        i === moduleIndex ? { ...module, [field]: value } : module
      )
    }));
  };

  const addLesson = (moduleIndex) => {
    setFormData(prev => ({
      ...prev,
      modules: prev.modules.map((module, i) => 
        i === moduleIndex 
          ? { 
              ...module, 
              lessons: [...module.lessons, {
                title: '',
                type: 'video',
                content: '',
                duration: ''
              }]
            }
          : module
      )
    }));
  };

  const removeLesson = (moduleIndex, lessonIndex) => {
    setFormData(prev => ({
      ...prev,
      modules: prev.modules.map((module, i) => 
        i === moduleIndex 
          ? { 
              ...module, 
              lessons: module.lessons.filter((_, j) => j !== lessonIndex)
            }
          : module
      )
    }));
  };

  const updateLesson = (moduleIndex, lessonIndex, field, value) => {
    setFormData(prev => ({
      ...prev,
      modules: prev.modules.map((module, i) => 
        i === moduleIndex 
          ? { 
              ...module, 
              lessons: module.lessons.map((lesson, j) => 
                j === lessonIndex ? { ...lesson, [field]: value } : lesson
              )
            }
          : module
      )
    }));
  };

  const handleSave = async (status = 'draft') => {
    setIsSaving(true);
    try {
      // Simulate API call
      await new Promise(resolve => setTimeout(resolve, 1000));
      
      toast.success(t('instructor.courseSaved', { defaultValue: 'Course saved successfully!' }));
      
      if (status === 'published') {
        navigate('/instructor/courses');
      }
    } catch (error) {
      toast.error(t('instructor.saveError', { defaultValue: 'Failed to save course' }));
    } finally {
      setIsSaving(false);
    }
  };

  if (previewMode) {
    return (
      <div className="animate-fade-in">
        <div className="flex items-center justify-between mb-8">
          <div>
            <h1 className="text-3xl font-bold text-white mb-2">{formData.title}</h1>
            <p className="text-slate-400">{formData.description}</p>
          </div>
          <button
            onClick={() => setPreviewMode(false)}
            className="btn-ghost"
          >
            <X className="w-4 h-4" />
            {t('instructor.exitPreview', { defaultValue: 'Exit Preview' })}
          </button>
        </div>

        <div className="card">
          <div className="aspect-video bg-slate-800 rounded-lg mb-6 flex items-center justify-center">
            <Video className="w-16 h-16 text-slate-600" />
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">
            <div>
              <h3 className="text-lg font-semibold text-white mb-3">
                {t('instructor.whatYouLearn', { defaultValue: 'What you\'ll learn' })}
              </h3>
              <ul className="space-y-2">
                {formData.objectives.filter(obj => obj.trim()).map((objective, index) => (
                  <li key={index} className="flex items-start gap-2 text-slate-300">
                    <span className="text-primary-400 mt-1">✓</span>
                    <span>{objective}</span>
                  </li>
                ))}
              </ul>
            </div>

            <div>
              <h3 className="text-lg font-semibold text-white mb-3">
                {t('instructor.requirements', { defaultValue: 'Requirements' })}
              </h3>
              <ul className="space-y-2">
                {formData.requirements.filter(req => req.trim()).map((requirement, index) => (
                  <li key={index} className="flex items-start gap-2 text-slate-300">
                    <span className="text-primary-400 mt-1">•</span>
                    <span>{requirement}</span>
                  </li>
                ))}
              </ul>
            </div>
          </div>

          <div>
            <h3 className="text-lg font-semibold text-white mb-3">
              {t('instructor.courseContent', { defaultValue: 'Course Content' })}
            </h3>
            <div className="space-y-4">
              {formData.modules.map((module, moduleIndex) => (
                <div key={moduleIndex} className="border border-slate-700/50 rounded-lg p-4">
                  <h4 className="font-medium text-white mb-2">{module.title}</h4>
                  <div className="space-y-2">
                    {module.lessons.map((lesson, lessonIndex) => (
                      <div key={lessonIndex} className="flex items-center justify-between text-sm text-slate-400">
                        <span>{lesson.title}</span>
                        <span>{lesson.duration}</span>
                      </div>
                    ))}
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="animate-fade-in">
      <div className="flex items-center justify-between mb-8">
        <div>
          <h1 className="text-3xl font-bold text-white mb-2">
            {t('instructor.createCourse', { defaultValue: 'Create Course' })}
          </h1>
          <p className="text-slate-400">
            {t('instructor.createCourseDesc', { defaultValue: 'Create and publish your new course' })}
          </p>
        </div>
        <div className="flex items-center gap-3">
          <button
            onClick={() => setPreviewMode(true)}
            className="btn-ghost flex items-center gap-2"
          >
            <Eye className="w-4 h-4" />
            {t('instructor.preview', { defaultValue: 'Preview' })}
          </button>
          <button
            onClick={() => handleSave('draft')}
            disabled={isSaving}
            className="btn-ghost flex items-center gap-2"
          >
            <Save className="w-4 h-4" />
            {isSaving ? t('common.saving', { defaultValue: 'Saving...' }) : t('instructor.saveDraft', { defaultValue: 'Save Draft' })}
          </button>
          <button
            onClick={() => handleSave('published')}
            disabled={isSaving}
            className="btn-primary flex items-center gap-2"
          >
            <Upload className="w-4 h-4" />
            {isSaving ? t('common.publishing', { defaultValue: 'Publishing...' }) : t('instructor.publish', { defaultValue: 'Publish' })}
          </button>
        </div>
      </div>

      <div className="space-y-6">
        {/* Basic Information */}
        <div className="card">
          <h2 className="text-xl font-bold text-white mb-6">
            {t('instructor.basicInfo', { defaultValue: 'Basic Information' })}
          </h2>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <label className="block text-sm font-medium text-slate-300 mb-2">
                {t('instructor.courseTitle', { defaultValue: 'Course Title' })}
              </label>
              <input
                type="text"
                value={formData.title}
                onChange={(e) => handleInputChange('title', e.target.value)}
                placeholder={t('instructor.courseTitlePlaceholder', { defaultValue: 'Enter course title' })}
                className="w-full px-4 py-2 bg-slate-800/50 border border-slate-600/50 rounded-lg text-white placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-primary-500 focus:border-transparent"
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-slate-300 mb-2">
                {t('instructor.category', { defaultValue: 'Category' })}
              </label>
              <select
                value={formData.category}
                onChange={(e) => handleInputChange('category', e.target.value)}
                className="w-full px-4 py-2 bg-slate-800/50 border border-slate-600/50 rounded-lg text-white focus:outline-none focus:ring-2 focus:ring-primary-500 focus:border-transparent"
              >
                <option value="">{t('instructor.selectCategory', { defaultValue: 'Select category' })}</option>
                <option value="development">Development</option>
                <option value="design">Design</option>
                <option value="business">Business</option>
                <option value="marketing">Marketing</option>
                <option value="photography">Photography</option>
              </select>
            </div>

            <div>
              <label className="block text-sm font-medium text-slate-300 mb-2">
                {t('instructor.level', { defaultValue: 'Level' })}
              </label>
              <select
                value={formData.level}
                onChange={(e) => handleInputChange('level', e.target.value)}
                className="w-full px-4 py-2 bg-slate-800/50 border border-slate-600/50 rounded-lg text-white focus:outline-none focus:ring-2 focus:ring-primary-500 focus:border-transparent"
              >
                <option value="beginner">{t('instructor.beginner', { defaultValue: 'Beginner' })}</option>
                <option value="intermediate">{t('instructor.intermediate', { defaultValue: 'Intermediate' })}</option>
                <option value="advanced">{t('instructor.advanced', { defaultValue: 'Advanced' })}</option>
              </select>
            </div>

            <div>
              <label className="block text-sm font-medium text-slate-300 mb-2">
                {t('instructor.price', { defaultValue: 'Price' })}
              </label>
              <input
                type="text"
                value={formData.price}
                onChange={(e) => handleInputChange('price', e.target.value)}
                placeholder={t('instructor.pricePlaceholder', { defaultValue: 'e.g. $99.99' })}
                className="w-full px-4 py-2 bg-slate-800/50 border border-slate-600/50 rounded-lg text-white placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-primary-500 focus:border-transparent"
              />
            </div>
          </div>

          <div className="mt-6">
            <label className="block text-sm font-medium text-slate-300 mb-2">
              {t('instructor.description', { defaultValue: 'Course Description' })}
            </label>
            <textarea
              value={formData.description}
              onChange={(e) => handleInputChange('description', e.target.value)}
              placeholder={t('instructor.descriptionPlaceholder', { defaultValue: 'Describe your course...' })}
              rows={4}
              className="w-full px-4 py-2 bg-slate-800/50 border border-slate-600/50 rounded-lg text-white placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-primary-500 focus:border-transparent resize-none"
            />
          </div>
        </div>

        {/* Learning Objectives */}
        <div className="card">
          <div className="flex items-center justify-between mb-6">
            <h2 className="text-xl font-bold text-white">
              {t('instructor.learningObjectives', { defaultValue: 'Learning Objectives' })}
            </h2>
            <button onClick={addObjective} className="btn-ghost flex items-center gap-2">
              <Plus className="w-4 h-4" />
              {t('instructor.addObjective', { defaultValue: 'Add Objective' })}
            </button>
          </div>

          <div className="space-y-3">
            {formData.objectives.map((objective, index) => (
              <div key={index} className="flex items-center gap-3">
                <input
                  type="text"
                  value={objective}
                  onChange={(e) => updateObjective(index, e.target.value)}
                  placeholder={t('instructor.objectivePlaceholder', { defaultValue: 'Enter learning objective...' })}
                  className="flex-1 px-4 py-2 bg-slate-800/50 border border-slate-600/50 rounded-lg text-white placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                />
                <button
                  onClick={() => removeObjective(index)}
                  className="p-2 rounded-lg text-slate-400 hover:text-red-400 hover:bg-slate-700/50 transition-colors"
                >
                  <Trash2 className="w-4 h-4" />
                </button>
              </div>
            ))}
          </div>
        </div>

        {/* Requirements */}
        <div className="card">
          <div className="flex items-center justify-between mb-6">
            <h2 className="text-xl font-bold text-white">
              {t('instructor.requirements', { defaultValue: 'Requirements' })}
            </h2>
            <button onClick={addRequirement} className="btn-ghost flex items-center gap-2">
              <Plus className="w-4 h-4" />
              {t('instructor.addRequirement', { defaultValue: 'Add Requirement' })}
            </button>
          </div>

          <div className="space-y-3">
            {formData.requirements.map((requirement, index) => (
              <div key={index} className="flex items-center gap-3">
                <input
                  type="text"
                  value={requirement}
                  onChange={(e) => updateRequirement(index, e.target.value)}
                  placeholder={t('instructor.requirementPlaceholder', { defaultValue: 'Enter requirement...' })}
                  className="flex-1 px-4 py-2 bg-slate-800/50 border border-slate-600/50 rounded-lg text-white placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                />
                <button
                  onClick={() => removeRequirement(index)}
                  className="p-2 rounded-lg text-slate-400 hover:text-red-400 hover:bg-slate-700/50 transition-colors"
                >
                  <Trash2 className="w-4 h-4" />
                </button>
              </div>
            ))}
          </div>
        </div>

        {/* Course Content */}
        <div className="card">
          <div className="flex items-center justify-between mb-6">
            <h2 className="text-xl font-bold text-white">
              {t('instructor.courseContent', { defaultValue: 'Course Content' })}
            </h2>
            <button onClick={addModule} className="btn-primary flex items-center gap-2">
              <Plus className="w-4 h-4" />
              {t('instructor.addModule', { defaultValue: 'Add Module' })}
            </button>
          </div>

          <div className="space-y-6">
            {formData.modules.map((module, moduleIndex) => (
              <div key={moduleIndex} className="border border-slate-700/50 rounded-lg p-6">
                <div className="flex items-center justify-between mb-4">
                  <input
                    type="text"
                    value={module.title}
                    onChange={(e) => updateModule(moduleIndex, 'title', e.target.value)}
                    placeholder={t('instructor.moduleTitle', { defaultValue: 'Module Title' })}
                    className="text-lg font-medium text-white bg-transparent border-b border-slate-600/50 focus:border-primary-500 outline-none placeholder-slate-500"
                  />
                  <button
                    onClick={() => removeModule(moduleIndex)}
                    className="p-2 rounded-lg text-slate-400 hover:text-red-400 hover:bg-slate-700/50 transition-colors"
                  >
                    <Trash2 className="w-4 h-4" />
                  </button>
                </div>

                <div className="space-y-3">
                  {module.lessons.map((lesson, lessonIndex) => (
                    <div key={lessonIndex} className="flex items-center gap-3 p-3 bg-slate-800/50 rounded-lg">
                      <select
                        value={lesson.type}
                        onChange={(e) => updateLesson(moduleIndex, lessonIndex, 'type', e.target.value)}
                        className="px-3 py-1.5 bg-slate-700/50 border border-slate-600/50 rounded text-white text-sm focus:outline-none focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                      >
                        <option value="video">Video</option>
                        <option value="text">Text</option>
                        <option value="quiz">Quiz</option>
                        <option value="assignment">Assignment</option>
                      </select>

                      <input
                        type="text"
                        value={lesson.title}
                        onChange={(e) => updateLesson(moduleIndex, lessonIndex, 'title', e.target.value)}
                        placeholder={t('instructor.lessonTitle', { defaultValue: 'Lesson Title' })}
                        className="flex-1 px-3 py-1.5 bg-slate-700/50 border border-slate-600/50 rounded text-white text-sm placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                      />

                      <input
                        type="text"
                        value={lesson.duration}
                        onChange={(e) => updateLesson(moduleIndex, lessonIndex, 'duration', e.target.value)}
                        placeholder={t('instructor.duration', { defaultValue: 'Duration' })}
                        className="w-24 px-3 py-1.5 bg-slate-700/50 border border-slate-600/50 rounded text-white text-sm placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                      />

                      <button
                        onClick={() => removeLesson(moduleIndex, lessonIndex)}
                        className="p-1.5 rounded-lg text-slate-400 hover:text-red-400 hover:bg-slate-700/50 transition-colors"
                      >
                        <Trash2 className="w-4 h-4" />
                      </button>
                    </div>
                  ))}

                  <button
                    onClick={() => addLesson(moduleIndex)}
                    className="w-full p-3 border-2 border-dashed border-slate-600/50 rounded-lg text-slate-400 hover:text-white hover:border-primary-500 transition-colors flex items-center justify-center gap-2"
                  >
                    <Plus className="w-4 h-4" />
                    {t('instructor.addLesson', { defaultValue: 'Add Lesson' })}
                  </button>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
