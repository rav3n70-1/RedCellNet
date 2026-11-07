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
  Droplets,
} from 'lucide-react';
import type { BloodGroup, DonationCenter } from '../types';
import { Modal } from '../components/common/Modal';
import { ConfirmDialog } from '../components/common/ConfirmDialog';
import { EmptyState } from '../components/common/EmptyState';
import { supabase } from '../lib/supabase';

interface FacilitiesPageProps {
  facilities: DonationCenter[];
  onRefresh: () => void;
}

const BLOOD_GROUPS: BloodGroup[] = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

const FACILITY_TYPES = [
  'Hospital Blood Bank',
  'Red Crescent Center',
  'Diagnostic & Transfusion Center',
  'Voluntary Blood Center',
];

const OPERATIONAL_STATUSES = [
  'Open',
  'Limited Stock',
  'Emergency Only',
  'Temporarily Closed',
];

const emptyInventory = (): Record<BloodGroup, number> => ({
  'A+': 0,
  'A-': 0,
  'B+': 0,
  'B-': 0,
  'AB+': 0,
  'AB-': 0,
  'O+': 0,
  'O-': 0,
});

export const FacilitiesPage: React.FC<FacilitiesPageProps> = ({ facilities, onRefresh }) => {
  const [searchQuery, setSearchQuery] = useState('');
  const [isAddModalOpen, setIsAddModalOpen] = useState(false);
  const [editingCenter, setEditingCenter] = useState<DonationCenter | null>(null);
  const [deletingCenter, setDeletingCenter] = useState<DonationCenter | null>(null);
  const [isProcessing, setIsProcessing] = useState(false);

  const [formData, setFormData] = useState({
    name: '',
    address: '',
    city: 'Dhaka',
    latitude: '23.8103',
    longitude: '90.4125',
    operating_hours: '9:00 AM - 5:00 PM',
    contact_number: '+8802',
    facility_type: 'Hospital Blood Bank',
    operational_status: 'Open',
    is_verified: true,
    blood_inventory: emptyInventory(),
  });

  const filteredFacilities = facilities.filter((f) => {
    const q = searchQuery.toLowerCase();
    return (
      (f.name || '').toLowerCase().includes(q) ||
      (f.address || '').toLowerCase().includes(q) ||
      (f.city || '').toLowerCase().includes(q) ||
      (f.facility_type || '').toLowerCase().includes(q)
    );
  });

  const openAddModal = () => {
    setFormData({
      name: '',
      address: '',
      city: 'Dhaka',
      latitude: '23.8103',
      longitude: '90.4125',
      operating_hours: '24/7',
      contact_number: '+880',
      facility_type: 'Hospital Blood Bank',
      operational_status: 'Open',
      is_verified: true,
      blood_inventory: emptyInventory(),
    });
    setIsAddModalOpen(true);
  };

  const openEditModal = (center: DonationCenter) => {
    const inv = emptyInventory();
    if (center.blood_inventory) {
      for (const bg of BLOOD_GROUPS) {
        inv[bg] = Number(center.blood_inventory[bg]) || 0;
      }
    }
    setEditingCenter(center);
    setFormData({
      name: center.name || '',
      address: center.address || '',
      city: center.city || 'Dhaka',
      latitude: center.latitude != null ? String(center.latitude) : '',
      longitude: center.longitude != null ? String(center.longitude) : '',
      operating_hours: center.operating_hours || '',
      contact_number: center.contact_info || center.contact_number || '',
      facility_type: center.facility_type || 'Hospital Blood Bank',
      operational_status: center.operational_status || 'Open',
      is_verified: Boolean(center.is_verified),
      blood_inventory: inv,
    });
  };

  const handleSaveFacility = async (e: React.FormEvent) => {
    e.preventDefault();
    const lat = parseFloat(formData.latitude);
    const lng = parseFloat(formData.longitude);

    if (
      !formData.name.trim() ||
      !formData.address.trim() ||
      Number.isNaN(lat) ||
      Number.isNaN(lng) ||
      lat < -90 ||
      lat > 90 ||
      lng < -180 ||
      lng > 180
    ) {
      alert('Please fill out facility name, street address, and valid geographic coordinates.');
      return;
    }

    setIsProcessing(true);
    try {
      const payload = {
        name: formData.name.trim(),
        address: formData.address.trim(),
        city: formData.city.trim() || 'Dhaka',
        latitude: lat,
        longitude: lng,
        operating_hours: formData.operating_hours.trim(),
        contact_info: formData.contact_number.trim(),
        contact_number: formData.contact_number.trim(),
        facility_type: formData.facility_type,
        operational_status: formData.operational_status,
        is_verified: formData.is_verified,
        blood_inventory: formData.blood_inventory,
        updated_at: new Date().toISOString(),
      };

      if (editingCenter) {
        const { error } = await supabase
          .from('donation_centers')
          .update(payload)
          .eq('id', editingCenter.id);
        if (error) throw error;

        await supabase.rpc('record_admin_log', {
          p_action_type: 'update_donation_center',
          p_target_type: 'donation_center',
          p_target_id: editingCenter.id,
          p_details: { name: payload.name, status: payload.operational_status },
        });
        setEditingCenter(null);
      } else {
        const { data: inserted, error } = await supabase
          .from('donation_centers')
          .insert({
            ...payload,
            created_at: new Date().toISOString(),
          })
          .select('id')
          .maybeSingle();
        if (error) throw error;

        await supabase.rpc('record_admin_log', {
          p_action_type: 'create_donation_center',
          p_target_type: 'donation_center',
          p_target_id: inserted?.id ? String(inserted.id) : payload.name,
          p_details: { name: payload.name, city: payload.city },
        });
        setIsAddModalOpen(false);
      }
      onRefresh();
    } catch (err: unknown) {
      console.error('Error saving facility:', err);
      alert(err instanceof Error ? err.message : 'Failed to save blood center.');
    } finally {
      setIsProcessing(false);
    }
  };

  const handleDeleteFacility = async () => {
    if (!deletingCenter) return;
    setIsProcessing(true);
    try {
      const targetId = deletingCenter.id;
      const targetName = deletingCenter.name;
      const { error } = await supabase.from('donation_centers').delete().eq('id', targetId);
      if (error) throw error;

      await supabase.rpc('record_admin_log', {
        p_action_type: 'delete_donation_center',
        p_target_type: 'donation_center',
        p_target_id: targetId,
        p_details: { name: targetName },
      });

      setDeletingCenter(null);
      onRefresh();
    } catch (err: unknown) {
      console.error('Error deleting facility:', err);
      alert(err instanceof Error ? err.message : 'Failed to delete blood center.');
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
            placeholder="Search certified blood centers by name, city, or type..."
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
          {filteredFacilities.map((center) => {
            const isVerified = Boolean(center.is_verified);
            const hasCoords =
              center.latitude !== null &&
              center.latitude !== undefined &&
              center.longitude !== null &&
              center.longitude !== undefined &&
              !Number.isNaN(Number(center.latitude)) &&
              !Number.isNaN(Number(center.longitude));
            const status = center.operational_status || 'Open';
            const contact = center.contact_info || center.contact_number || '';
            const totalUnits = center.blood_inventory
              ? Object.values(center.blood_inventory).reduce((sum, n) => sum + (Number(n) || 0), 0)
              : 0;

            return (
              <div
                key={center.id}
                className="bg-white rounded-2xl p-5 border border-slate-200 shadow-xs hover:shadow-md transition-all flex flex-col justify-between"
              >
                <div>
                  <div className="flex items-start justify-between gap-3 mb-3">
                    <div className="flex items-start gap-3">
                      <div className="p-2.5 bg-red-50 text-red-600 rounded-xl shrink-0">
                        <Building2 className="w-5 h-5" />
                      </div>
                      <div>
                        <h4 className="font-bold text-sm text-slate-900 leading-tight">
                          {center.name}
                        </h4>
                        <div className="text-[11px] text-slate-500 font-medium mt-0.5">
                          {center.facility_type || 'Hospital Blood Bank'}
                        </div>
                        <div className="flex flex-wrap items-center gap-1.5 mt-1.5">
                          <span
                            className={`text-[10px] uppercase font-bold tracking-wider px-2 py-0.5 rounded-sm border inline-block ${
                              isVerified
                                ? 'text-emerald-700 bg-emerald-50 border-emerald-200'
                                : 'text-slate-600 bg-slate-100 border-slate-200'
                            }`}
                          >
                            {isVerified ? 'Verified Center' : 'Unverified'}
                          </span>
                          <span
                            className={`text-[10px] font-bold px-2 py-0.5 rounded-sm ${
                              status === 'Open'
                                ? 'bg-teal-50 text-teal-700'
                                : status === 'Temporarily Closed'
                                  ? 'bg-rose-50 text-rose-700'
                                  : 'bg-amber-50 text-amber-700'
                            }`}
                          >
                            {status}
                          </span>
                          {center.city && (
                            <span className="text-[10px] font-semibold text-slate-500 bg-slate-100 px-2 py-0.5 rounded-sm">
                              {center.city}
                            </span>
                          )}
                        </div>
                      </div>
                    </div>

                    <div className="flex items-center gap-1 shrink-0">
                      <button
                        onClick={() => openEditModal(center)}
                        className="p-1.5 text-slate-400 hover:text-slate-700 hover:bg-slate-100 rounded-lg"
                        title="Edit Center & Inventory"
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
                    {contact && (
                      <div className="flex items-center gap-2">
                        <Phone className="w-4 h-4 text-slate-400 shrink-0" />
                        <span>{contact}</span>
                      </div>
                    )}
                  </div>

                  {/* Inventory Stock Pills */}
                  {totalUnits > 0 && center.blood_inventory && (
                    <div className="mt-3.5 pt-3 border-t border-slate-100">
                      <div className="text-[10px] font-bold uppercase tracking-wider text-slate-400 mb-1.5 flex items-center gap-1">
                        <Droplets className="w-3 h-3 text-red-500" />
                        Reported Stock ({totalUnits} units)
                      </div>
                      <div className="flex flex-wrap gap-1">
                        {BLOOD_GROUPS.map((bg) => {
                          const qty = Number(center.blood_inventory?.[bg]) || 0;
                          if (qty <= 0) return null;
                          return (
                            <span
                              key={bg}
                              className="text-[10px] font-bold px-1.5 py-0.5 rounded bg-red-50 text-red-700 border border-red-100"
                            >
                              {bg}: {qty}
                            </span>
                          );
                        })}
                      </div>
                    </div>
                  )}
                </div>

                <div className="mt-5 pt-3.5 border-t border-slate-100 flex items-center justify-between text-xs">
                  <span className="text-slate-400 font-mono text-[11px]">
                    {hasCoords
                      ? `${Number(center.latitude).toFixed(4)}, ${Number(center.longitude).toFixed(4)}`
                      : 'Coordinates unset'}
                  </span>
                  {hasCoords && (
                    <a
                      href={`https://www.google.com/maps/search/?api=1&query=${center.latitude},${center.longitude}`}
                      target="_blank"
                      rel="noreferrer"
                      className="font-bold text-red-600 hover:text-red-700 flex items-center gap-1 hover:underline"
                    >
                      Open Maps <ExternalLink className="w-3 h-3" />
                    </a>
                  )}
                </div>
              </div>
            );
          })}
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
          title={editingCenter ? 'Edit Blood Center & Inventory' : 'Add New Blood Center'}
          maxWidth="lg"
        >
          <form onSubmit={handleSaveFacility} className="space-y-4">
            <div>
              <label className="text-xs font-semibold text-slate-700 block mb-1">
                Facility Name *
              </label>
              <input
                type="text"
                required
                placeholder="e.g. Bangladesh Red Crescent Blood Center"
                value={formData.name}
                onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                className="w-full px-3 py-2 text-xs border border-slate-200 rounded-xl focus:ring-2 focus:ring-red-500/20"
              />
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <div>
                <label className="text-xs font-semibold text-slate-700 block mb-1">
                  Facility Type
                </label>
                <select
                  value={formData.facility_type}
                  onChange={(e) => setFormData({ ...formData, facility_type: e.target.value })}
                  className="w-full px-3 py-2 text-xs border border-slate-200 rounded-xl"
                >
                  {FACILITY_TYPES.map((ft) => (
                    <option key={ft} value={ft}>
                      {ft}
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label className="text-xs font-semibold text-slate-700 block mb-1">
                  Operational Status
                </label>
                <select
                  value={formData.operational_status}
                  onChange={(e) => setFormData({ ...formData, operational_status: e.target.value })}
                  className="w-full px-3 py-2 text-xs border border-slate-200 rounded-xl"
                >
                  {OPERATIONAL_STATUSES.map((st) => (
                    <option key={st} value={st}>
                      {st}
                    </option>
                  ))}
                </select>
              </div>
            </div>

            <div className="grid grid-cols-3 gap-3">
              <div className="col-span-2">
                <label className="text-xs font-semibold text-slate-700 block mb-1">
                  Street Address *
                </label>
                <input
                  type="text"
                  required
                  placeholder="e.g. 7/5 Aurangzeb Road, Mohammadpur"
                  value={formData.address}
                  onChange={(e) => setFormData({ ...formData, address: e.target.value })}
                  className="w-full px-3 py-2 text-xs border border-slate-200 rounded-xl focus:ring-2 focus:ring-red-500/20"
                />
              </div>

              <div>
                <label className="text-xs font-semibold text-slate-700 block mb-1">
                  City / Region
                </label>
                <input
                  type="text"
                  placeholder="Dhaka"
                  value={formData.city}
                  onChange={(e) => setFormData({ ...formData, city: e.target.value })}
                  className="w-full px-3 py-2 text-xs border border-slate-200 rounded-xl focus:ring-2 focus:ring-red-500/20"
                />
              </div>
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="text-xs font-semibold text-slate-700 block mb-1">
                  Latitude *
                </label>
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
                <label className="text-xs font-semibold text-slate-700 block mb-1">
                  Longitude *
                </label>
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
                <label className="text-xs font-semibold text-slate-700 block mb-1">
                  Operating Hours
                </label>
                <input
                  type="text"
                  placeholder="24/7 or 9:00 AM - 8:00 PM"
                  value={formData.operating_hours}
                  onChange={(e) => setFormData({ ...formData, operating_hours: e.target.value })}
                  className="w-full px-3 py-2 text-xs border border-slate-200 rounded-xl"
                />
              </div>

              <div>
                <label className="text-xs font-semibold text-slate-700 block mb-1">
                  Contact Phone
                </label>
                <input
                  type="text"
                  placeholder="+880..."
                  value={formData.contact_number}
                  onChange={(e) => setFormData({ ...formData, contact_number: e.target.value })}
                  className="w-full px-3 py-2 text-xs border border-slate-200 rounded-xl"
                />
              </div>
            </div>

            {/* Blood Inventory Grid */}
            <div className="p-3.5 bg-slate-50 rounded-xl border border-slate-200">
              <label className="text-xs font-bold text-slate-700 block mb-2">
                Available Blood Units Inventory (Optional)
              </label>
              <div className="grid grid-cols-4 sm:grid-cols-8 gap-2">
                {BLOOD_GROUPS.map((bg) => (
                  <div key={bg} className="text-center">
                    <span className="text-[11px] font-extrabold text-red-700 block mb-1">{bg}</span>
                    <input
                      type="number"
                      min="0"
                      value={formData.blood_inventory[bg]}
                      onChange={(e) =>
                        setFormData({
                          ...formData,
                          blood_inventory: {
                            ...formData.blood_inventory,
                            [bg]: Math.max(0, parseInt(e.target.value, 10) || 0),
                          },
                        })
                      }
                      className="w-full px-1.5 py-1 text-center text-xs bg-white border border-slate-200 rounded-lg font-bold"
                    />
                  </div>
                ))}
              </div>
            </div>

            <div className="flex items-center gap-2 pt-1">
              <input
                type="checkbox"
                id="is_verified"
                checked={formData.is_verified}
                onChange={(e) => setFormData({ ...formData, is_verified: e.target.checked })}
                className="w-4 h-4 text-red-600 rounded-md border-slate-300 focus:ring-red-500"
              />
              <label htmlFor="is_verified" className="text-xs font-medium text-slate-700">
                Mark as Official Verified Blood Center / Facility
              </label>
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
