// admin_panel/src/pages/FacilitiesPage.tsx
import React, { useState } from 'react';
import {
  Building2,
  Plus,
  Search,
  MapPin,
  Clock,
  Phone,
  ExternalLink,
  Edit2,
  Trash2,
} from 'lucide-react';
import type { DonationCenter } from '../types';
import { Modal } from '../components/common/Modal';
import { ConfirmDialog } from '../components/common/ConfirmDialog';
import { EmptyState } from '../components/common/EmptyState';
import { supabase } from '../lib/supabase';

interface FacilitiesPageProps {
  facilities: DonationCenter[];
  onRefresh: () => void;
}

export const FacilitiesPage: React.FC<FacilitiesPageProps> = ({ facilities, onRefresh }) => {
  const [searchQuery, setSearchQuery] = useState('');
  const [isAddModalOpen, setIsAddModalOpen] = useState(false);
  const [editingCenter, setEditingCenter] = useState<DonationCenter | null>(null);
  const [deletingCenter, setDeletingCenter] = useState<DonationCenter | null>(null);
  const [isProcessing, setIsProcessing] = useState(false);

  // Form state
  const [formData, setFormData] = useState({
    name: '',
    address: '',
    latitude: '23.8103',
    longitude: '90.4125',
    operating_hours: '9:00 AM - 5:00 PM',
    contact_number: '+8802',
  });

  const filteredFacilities = facilities.filter(
    (f) =>
      (f.name || '').toLowerCase().includes(searchQuery.toLowerCase()) ||
      (f.address || '').toLowerCase().includes(searchQuery.toLowerCase())
  );

  const openAddModal = () => {
    setFormData({
      name: '',
      address: '',
      latitude: '23.8103',
      longitude: '90.4125',
      operating_hours: '9:00 AM - 5:00 PM',
      contact_number: '+8802',
    });
    setIsAddModalOpen(true);
  };

  const openEditModal = (center: DonationCenter) => {
    setEditingCenter(center);
    setFormData({
      name: center.name,
      address: center.address,
      latitude: center.latitude.toString(),
      longitude: center.longitude.toString(),
      operating_hours: center.operating_hours || '',
      contact_number: center.contact_number || '',
    });
  };

  const handleSaveFacility = async (e: React.FormEvent) => {
    e.preventDefault();
    const lat = parseFloat(formData.latitude);
    const lng = parseFloat(formData.longitude);

    if (!formData.name.trim() || !formData.address.trim() || isNaN(lat) || isNaN(lng)) {
      alert('Please fill out all required fields with valid coordinates.');
      return;
    }

    setIsProcessing(true);
    try {
      if (editingCenter) {
        await supabase
          .from('donation_centers')
          .update({
            name: formData.name.trim(),
            address: formData.address.trim(),
            latitude: lat,
            longitude: lng,
            operating_hours: formData.operating_hours.trim(),
            contact_number: formData.contact_number.trim(),
          })
          .eq('id', editingCenter.id);
        setEditingCenter(null);
      } else {
        await supabase.from('donation_centers').insert({
          name: formData.name.trim(),
          address: formData.address.trim(),
          latitude: lat,
          longitude: lng,
          operating_hours: formData.operating_hours.trim(),
          contact_number: formData.contact_number.trim(),
          created_at: new Date().toISOString(),
        });
        setIsAddModalOpen(false);
      }
      onRefresh();
    } catch (err) {
      console.error('Error saving facility:', err);
    } finally {
      setIsProcessing(false);
    }
  };

  const handleDeleteFacility = async () => {
    if (!deletingCenter) return;
    setIsProcessing(true);
    try {
      await supabase.from('donation_centers').delete().eq('id', deletingCenter.id);
      setDeletingCenter(null);
      onRefresh();
    } catch (err) {
      console.error('Error deleting facility:', err);
    } finally {
      setIsProcessing(false);
    }
  };

  return (
    <div className="space-y-6">
      {/* Top action bar */}
      <div className="flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-4">
        <div className="relative flex-1 max-w-md">
          <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            placeholder="Search certified blood centers..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full pl-10 pr-4 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-hidden focus:ring-2 focus:ring-red-500/20 focus:border-red-500"
          />
        </div>

        <button
          onClick={openAddModal}
          className="inline-flex items-center justify-center gap-2 px-4 py-2.5 bg-red-600 hover:bg-red-700 text-white font-bold text-sm rounded-xl shadow-xs transition-colors"
        >
          <Plus className="w-4 h-4" />
          Add Blood Center
        </button>
      </div>

      {/* Facilities Grid */}
      {filteredFacilities.length === 0 ? (
        <EmptyState
          icon={Building2}
          title="No Blood Centers Found"
          description={
            searchQuery
              ? 'No centers match your search. Try searching a different hospital or location.'
              : 'No verified blood banks or donation centers are registered yet.'
          }
          actionText="+ Add First Center"
          onAction={openAddModal}
        />
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-5">
          {filteredFacilities.map((center) => (
            <div
              key={center.id}
              className="bg-white rounded-2xl p-5 border border-slate-200 shadow-xs hover:shadow-md transition-all flex flex-col justify-between"
            >
              <div>
                <div className="flex items-start justify-between gap-3 mb-3">
                  <div className="flex items-center gap-3">
                    <div className="p-2.5 bg-red-50 text-red-600 rounded-xl">
                      <Building2 className="w-5 h-5" />
                    </div>
                    <div>
                      <h4 className="font-bold text-sm text-slate-900 leading-tight">{center.name}</h4>
                      <span className="text-[10px] uppercase font-bold tracking-wider text-emerald-600 bg-emerald-50 px-2 py-0.5 rounded-sm border border-emerald-200 inline-block mt-1">
                        Verified Center
                      </span>
                    </div>
                  </div>

                  <div className="flex items-center gap-1">
                    <button
                      onClick={() => openEditModal(center)}
                      className="p-1.5 text-slate-400 hover:text-slate-700 hover:bg-slate-100 rounded-lg"
                      title="Edit Center"
                    >
                      <Edit2 className="w-3.5 h-3.5" />
                    </button>
                    <button
                      onClick={() => setDeletingCenter(center)}
                      className="p-1.5 text-slate-400 hover:text-rose-600 hover:bg-rose-50 rounded-lg"
                      title="Delete Center"
                    >
                      <Trash2 className="w-3.5 h-3.5" />
                    </button>
                  </div>
                </div>

                <div className="space-y-2 text-xs text-slate-600 mt-4">
                  <div className="flex items-start gap-2">
                    <MapPin className="w-4 h-4 text-slate-400 shrink-0 mt-0.5" />
                    <span>{center.address}</span>
                  </div>
                  {center.operating_hours && (
                    <div className="flex items-center gap-2">
                      <Clock className="w-4 h-4 text-slate-400 shrink-0" />
                      <span>{center.operating_hours}</span>
                    </div>
                  )}
                  {center.contact_number && (
                    <div className="flex items-center gap-2">
                      <Phone className="w-4 h-4 text-slate-400 shrink-0" />
                      <span>{center.contact_number}</span>
                    </div>
                  )}
                </div>
              </div>

              <div className="mt-5 pt-3.5 border-t border-slate-100 flex items-center justify-between text-xs">
                <span className="text-slate-400 font-mono text-[11px]">
                  {center.latitude.toFixed(4)}, {center.longitude.toFixed(4)}
                </span>
                <a
                  href={`https://www.google.com/maps/search/?api=1&query=${center.latitude},${center.longitude}`}
                  target="_blank"
                  rel="noreferrer"
                  className="font-bold text-red-600 hover:text-red-700 flex items-center gap-1 hover:underline"
                >
                  Open Maps <ExternalLink className="w-3 h-3" />
                </a>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Add / Edit Center Modal */}
      {(isAddModalOpen || editingCenter) && (
        <Modal
          isOpen={true}
          onClose={() => {
            setIsAddModalOpen(false);
            setEditingCenter(null);
          }}
          title={editingCenter ? 'Edit Blood Center' : 'Add New Blood Center'}
          maxWidth="md"
        >
          <form onSubmit={handleSaveFacility} className="space-y-4">
            <div>
              <label className="text-xs font-semibold text-slate-700 block mb-1">Facility Name *</label>
              <input
                type="text"
                required
                placeholder="e.g. Bangladesh Red Crescent Blood Center"
                value={formData.name}
                onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                className="w-full px-3 py-2 text-xs border border-slate-200 rounded-xl focus:ring-2 focus:ring-red-500/20"
              />
            </div>

            <div>
              <label className="text-xs font-semibold text-slate-700 block mb-1">Street Address *</label>
              <input
                type="text"
                required
                placeholder="e.g. 7/5 Aurangzeb Road, Mohammadpur, Dhaka"
                value={formData.address}
                onChange={(e) => setFormData({ ...formData, address: e.target.value })}
                className="w-full px-3 py-2 text-xs border border-slate-200 rounded-xl focus:ring-2 focus:ring-red-500/20"
              />
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="text-xs font-semibold text-slate-700 block mb-1">Latitude *</label>
                <input
                  type="text"
                  required
                  placeholder="23.8103"
                  value={formData.latitude}
                  onChange={(e) => setFormData({ ...formData, latitude: e.target.value })}
                  className="w-full px-3 py-2 text-xs border border-slate-200 rounded-xl focus:ring-2 focus:ring-red-500/20 font-mono"
                />
              </div>

              <div>
                <label className="text-xs font-semibold text-slate-700 block mb-1">Longitude *</label>
                <input
                  type="text"
                  required
                  placeholder="90.4125"
                  value={formData.longitude}
                  onChange={(e) => setFormData({ ...formData, longitude: e.target.value })}
                  className="w-full px-3 py-2 text-xs border border-slate-200 rounded-xl focus:ring-2 focus:ring-red-500/20 font-mono"
                />
              </div>
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="text-xs font-semibold text-slate-700 block mb-1">Operating Hours</label>
                <input
                  type="text"
                  placeholder="24/7 or 9:00 AM - 8:00 PM"
                  value={formData.operating_hours}
                  onChange={(e) => setFormData({ ...formData, operating_hours: e.target.value })}
                  className="w-full px-3 py-2 text-xs border border-slate-200 rounded-xl"
                />
              </div>

              <div>
                <label className="text-xs font-semibold text-slate-700 block mb-1">Contact Phone</label>
                <input
                  type="text"
                  placeholder="+880..."
                  value={formData.contact_number}
                  onChange={(e) => setFormData({ ...formData, contact_number: e.target.value })}
                  className="w-full px-3 py-2 text-xs border border-slate-200 rounded-xl"
                />
              </div>
            </div>

            <div className="pt-4 border-t border-slate-100 flex justify-end gap-2.5">
              <button
                type="button"
                onClick={() => {
                  setIsAddModalOpen(false);
                  setEditingCenter(null);
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
                {isProcessing ? 'Saving...' : editingCenter ? 'Update Center' : 'Save Center'}
              </button>
            </div>
          </form>
        </Modal>
      )}

      {/* Delete Confirmation */}
      <ConfirmDialog
        isOpen={!!deletingCenter}
        onClose={() => setDeletingCenter(null)}
        onConfirm={handleDeleteFacility}
        title="Delete Blood Center?"
        message={`Are you sure you want to remove "${deletingCenter?.name}" from verified blood facilities?`}
        confirmText="Delete Facility"
        isLoading={isProcessing}
      />
    </div>
  );
};
