// admin_panel/src/pages/ContentPage.tsx
import React, { useState } from 'react';
import {
  BookOpen,
  Plus,
  Search,
  Award,
  Edit2,
  Trash2,
  Layers,
  Globe2,
} from 'lucide-react';
import type { EducationalContent } from '../types';
import { Modal } from '../components/common/Modal';
import { ConfirmDialog } from '../components/common/ConfirmDialog';
import { EmptyState } from '../components/common/EmptyState';
import { supabase } from '../lib/supabase';

interface ContentPageProps {
  content: EducationalContent[];
  onRefresh: () => void;
}

const CATEGORIES = [
  'Eligibility & Requirements',
  'Donation Process',
  'Health Benefits',
  'Myths vs Facts',
  'Patient Care',
];

export const ContentPage: React.FC<ContentPageProps> = ({ content, onRefresh }) => {
  const [searchQuery, setSearchQuery] = useState('');
  const [categoryFilter, setCategoryFilter] = useState<string>('all');
  const [isAddModalOpen, setIsAddModalOpen] = useState(false);
  const [editingArticle, setEditingArticle] = useState<EducationalContent | null>(null);
  const [deletingArticle, setDeletingArticle] = useState<EducationalContent | null>(null);
  const [isProcessing, setIsProcessing] = useState(false);

  // Form State
  const [formData, setFormData] = useState({
    title_en: '',
    title_bn: '',
    content_en: '',
    content_bn: '',
    category: 'Eligibility & Requirements',
    order: 1,
    points: 1,
    image_url: '',
  });

  const filteredContent = content.filter((c) => {
    const query = searchQuery.toLowerCase();
    const matchesSearch =
      (c.title_en || '').toLowerCase().includes(query) ||
      (c.title_bn || '').toLowerCase().includes(query) ||
      (c.category || '').toLowerCase().includes(query);

    const matchesCategory = categoryFilter === 'all' || c.category === categoryFilter;

    return matchesSearch && matchesCategory;
  });

  const openAddModal = () => {
    setFormData({
      title_en: '',
      title_bn: '',
      content_en: '',
      content_bn: '',
      category: 'Eligibility & Requirements',
      order: content.length + 1,
      points: 1,
      image_url: '',
    });
    setIsAddModalOpen(true);
  };

  const openEditModal = (article: EducationalContent) => {
    setEditingArticle(article);
    setFormData({
      title_en: article.title_en || '',
      title_bn: article.title_bn || '',
      content_en: article.content_en || '',
      content_bn: article.content_bn || '',
      category: article.category || 'Eligibility & Requirements',
      order: article.order || 1,
      points: article.points || 1,
      image_url: article.image_url || '',
    });
  };

  const handleSaveArticle = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!formData.title_en.trim() || !formData.content_en.trim()) {
      alert('Please fill out at least English Title and Content.');
      return;
    }

    setIsProcessing(true);
    try {
      const payload = {
        title_en: formData.title_en.trim(),
        title_bn: formData.title_bn.trim() || formData.title_en.trim(),
        content_en: formData.content_en.trim(),
        content_bn: formData.content_bn.trim() || formData.content_en.trim(),
        category: formData.category,
        order: Number(formData.order) || 1,
        points: Number(formData.points) || 1,
        image_url: formData.image_url.trim() || null,
      };

      if (editingArticle) {
        await supabase.from('educational_content').update(payload).eq('id', editingArticle.id);
        setEditingArticle(null);
      } else {
        await supabase.from('educational_content').insert({
          ...payload,
          created_at: new Date().toISOString(),
        });
        setIsAddModalOpen(false);
      }
      onRefresh();
    } catch (err) {
      console.error('Error saving article:', err);
    } finally {
      setIsProcessing(false);
    }
  };

  const handleDeleteArticle = async () => {
    if (!deletingArticle) return;
    setIsProcessing(true);
    try {
      await supabase.from('educational_content').delete().eq('id', deletingArticle.id);
      setDeletingArticle(null);
      onRefresh();
    } catch (err) {
      console.error('Error deleting educational content:', err);
    } finally {
      setIsProcessing(false);
    }
  };

  return (
    <div className="space-y-6">
      {/* Top action bar */}
      <div className="flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-4">
        <div className="flex items-center gap-3 flex-1 max-w-xl">
          <div className="relative flex-1">
            <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
            <input
              type="text"
              placeholder="Search articles by English or Bengali title..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="w-full pl-10 pr-4 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-hidden focus:ring-2 focus:ring-red-500/20 focus:border-red-500"
            />
          </div>

          <div className="bg-white border border-slate-200 rounded-xl px-3 py-2 text-xs">
            <select
              value={categoryFilter}
              onChange={(e) => setCategoryFilter(e.target.value)}
              className="bg-transparent font-medium text-slate-700 focus:outline-hidden"
            >
              <option value="all">All Categories</option>
              {CATEGORIES.map((cat) => (
                <option key={cat} value={cat}>
                  {cat}
                </option>
              ))}
            </select>
          </div>
        </div>

        <button
          onClick={openAddModal}
          className="inline-flex items-center justify-center gap-2 px-4 py-2.5 bg-red-600 hover:bg-red-700 text-white font-bold text-sm rounded-xl shadow-xs transition-colors shrink-0"
        >
          <Plus className="w-4 h-4" />
          Add Health Guide
        </button>
      </div>

      {/* Articles Grid */}
      {filteredContent.length === 0 ? (
        <EmptyState
          icon={BookOpen}
          title="No Articles Found"
          description={
            searchQuery || categoryFilter !== 'all'
              ? 'No guides match your search or category filter.'
              : 'No educational articles published yet.'
          }
          actionText="+ Publish First Guide"
          onAction={openAddModal}
        />
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
          {filteredContent.map((article) => (
            <div
              key={article.id}
              className="bg-white rounded-2xl border border-slate-200 shadow-xs hover:shadow-md transition-all flex flex-col justify-between overflow-hidden"
            >
              <div>
                {/* Image preview banner */}
                {article.image_url ? (
                  <div className="h-36 w-full bg-slate-100 overflow-hidden relative">
                    <img
                      src={article.image_url}
                      alt={article.title_en}
                      className="w-full h-full object-cover"
                      onError={(e) => {
                        (e.target as HTMLElement).style.display = 'none';
                      }}
                    />
                    <div className="absolute top-2.5 right-2.5 bg-slate-900/70 text-white font-bold text-[10px] px-2 py-0.5 rounded-md backdrop-blur-xs">
                      #{article.order}
                    </div>
                  </div>
                ) : (
                  <div className="h-16 w-full bg-gradient-to-r from-red-50 to-rose-50 border-b border-red-100 flex items-center justify-between px-4">
                    <span className="text-[11px] font-bold text-red-700 uppercase tracking-wider">
                      {article.category}
                    </span>
                    <span className="text-xs font-bold text-slate-400">#{article.order}</span>
                  </div>
                )}

                <div className="p-5">
                  <div className="flex items-center gap-2 mb-1.5 text-xs text-slate-500 font-semibold">
                    <Layers className="w-3.5 h-3.5 text-slate-400" />
                    <span>{article.category}</span>
                  </div>

                  <h4 className="text-base font-bold text-slate-900 line-clamp-1">{article.title_en}</h4>
                  {article.title_bn && article.title_bn !== article.title_en && (
                    <h5 className="text-xs font-medium text-slate-500 line-clamp-1 mt-0.5">
                      {article.title_bn}
                    </h5>
                  )}

                  <p className="text-xs text-slate-600 line-clamp-3 mt-2.5 leading-relaxed">
                    {article.content_en}
                  </p>
                </div>
              </div>

              <div className="p-4 bg-slate-50/70 border-t border-slate-100 flex items-center justify-between text-xs">
                <span className="flex items-center gap-1 font-bold text-amber-700 bg-amber-50 px-2 py-0.5 rounded-md border border-amber-200">
                  <Award className="w-3 h-3 text-amber-600" />+{article.points} pt read reward
                </span>

                <div className="flex items-center gap-1">
                  <button
                    onClick={() => openEditModal(article)}
                    className="p-1.5 text-slate-400 hover:text-slate-700 hover:bg-slate-200/60 rounded-lg transition-colors"
                    title="Edit Guide"
                  >
                    <Edit2 className="w-4 h-4" />
                  </button>
                  <button
                    onClick={() => setDeletingArticle(article)}
                    className="p-1.5 text-slate-400 hover:text-rose-600 hover:bg-rose-50 rounded-lg transition-colors"
                    title="Delete Guide"
                  >
                    <Trash2 className="w-4 h-4" />
                  </button>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Add / Edit Article Modal */}
      {(isAddModalOpen || editingArticle) && (
        <Modal
          isOpen={true}
          onClose={() => {
            setIsAddModalOpen(false);
            setEditingArticle(null);
          }}
          title={editingArticle ? 'Edit Educational Guide' : 'Publish New Educational Guide'}
          maxWidth="2xl"
        >
          <form onSubmit={handleSaveArticle} className="space-y-4">
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div>
                <label className="text-xs font-semibold text-slate-700 block mb-1">
                  English Title *
                </label>
                <input
                  type="text"
                  required
                  placeholder="e.g. Who can donate blood?"
                  value={formData.title_en}
                  onChange={(e) => setFormData({ ...formData, title_en: e.target.value })}
                  className="w-full px-3 py-2 text-xs border border-slate-200 rounded-xl focus:ring-2 focus:ring-red-500/20"
                />
              </div>

              <div>
                <label className="text-xs font-semibold text-slate-700 block mb-1 flex items-center gap-1">
                  <Globe2 className="w-3 h-3 text-red-500" />
                  Bengali Title (বাংলা)
                </label>
                <input
                  type="text"
                  placeholder="e.g. কারা রক্ত দিতে পারবেন?"
                  value={formData.title_bn}
                  onChange={(e) => setFormData({ ...formData, title_bn: e.target.value })}
                  className="w-full px-3 py-2 text-xs border border-slate-200 rounded-xl focus:ring-2 focus:ring-red-500/20"
                />
              </div>
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
              <div>
                <label className="text-xs font-semibold text-slate-700 block mb-1">Category</label>
                <select
                  value={formData.category}
                  onChange={(e) => setFormData({ ...formData, category: e.target.value })}
                  className="w-full px-3 py-2 text-xs border border-slate-200 rounded-xl"
                >
                  {CATEGORIES.map((cat) => (
                    <option key={cat} value={cat}>
                      {cat}
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label className="text-xs font-semibold text-slate-700 block mb-1">Display Order</label>
                <input
                  type="number"
                  min="1"
                  value={formData.order}
                  onChange={(e) => setFormData({ ...formData, order: parseInt(e.target.value) || 1 })}
                  className="w-full px-3 py-2 text-xs border border-slate-200 rounded-xl"
                />
              </div>

              <div>
                <label className="text-xs font-semibold text-slate-700 block mb-1">
                  Reward Points (Life Points)
                </label>
                <input
                  type="number"
                  min="1"
                  value={formData.points}
                  onChange={(e) => setFormData({ ...formData, points: parseInt(e.target.value) || 1 })}
                  className="w-full px-3 py-2 text-xs border border-slate-200 rounded-xl"
                />
              </div>
            </div>

            <div>
              <label className="text-xs font-semibold text-slate-700 block mb-1">
                Thumbnail Image URL (optional)
              </label>
              <input
                type="url"
                placeholder="https://images.unsplash.com/..."
                value={formData.image_url}
                onChange={(e) => setFormData({ ...formData, image_url: e.target.value })}
                className="w-full px-3 py-2 text-xs border border-slate-200 rounded-xl font-mono"
              />
            </div>

            <div>
              <label className="text-xs font-semibold text-slate-700 block mb-1">
                English Content * (Markdown supported)
              </label>
              <textarea
                rows={4}
                required
                placeholder="Write the guide content in English..."
                value={formData.content_en}
                onChange={(e) => setFormData({ ...formData, content_en: e.target.value })}
                className="w-full px-3 py-2 text-xs border border-slate-200 rounded-xl focus:ring-2 focus:ring-red-500/20 font-sans"
              />
            </div>

            <div>
              <label className="text-xs font-semibold text-slate-700 block mb-1 flex items-center gap-1">
                <Globe2 className="w-3 h-3 text-red-500" />
                Bengali Content (বাংলা বিবরণ)
              </label>
              <textarea
                rows={4}
                placeholder="বাংলা ভাষায় নির্দেশিকা ও তথ্য লিখুন..."
                value={formData.content_bn}
                onChange={(e) => setFormData({ ...formData, content_bn: e.target.value })}
                className="w-full px-3 py-2 text-xs border border-slate-200 rounded-xl focus:ring-2 focus:ring-red-500/20 font-sans"
              />
            </div>

            <div className="pt-4 border-t border-slate-100 flex justify-end gap-2.5">
              <button
                type="button"
                onClick={() => {
                  setIsAddModalOpen(false);
                  setEditingArticle(null);
                }}
                className="px-4 py-2 text-xs font-semibold text-slate-700 bg-slate-100 rounded-xl hover:bg-slate-200"
              >
                Cancel
              </button>
              <button
                type="submit"
                disabled={isProcessing}
                className="px-4 py-2 text-xs font-semibold text-white bg-red-600 hover:bg-red-700 rounded-xl shadow-xs"
              >
                {isProcessing ? 'Saving...' : editingArticle ? 'Update Article' : 'Publish Article'}
              </button>
            </div>
          </form>
        </Modal>
      )}

      {/* Delete Confirmation */}
      <ConfirmDialog
        isOpen={!!deletingArticle}
        onClose={() => setDeletingArticle(null)}
        onConfirm={handleDeleteArticle}
        title="Delete Health Guide?"
        message={`Are you sure you want to delete "${deletingArticle?.title_en}"? It will no longer appear on mobile apps.`}
        confirmText="Delete Guide"
        isLoading={isProcessing}
      />
    </div>
  );
};
