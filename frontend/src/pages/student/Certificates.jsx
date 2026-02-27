import React, { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Award, Download, Share2, Calendar, Loader2 } from 'lucide-react';
import api from '../../services/api';
import toast from 'react-hot-toast';

export default function CertificatesPage() {
  const { t } = useTranslation();
  const [certs, setCerts] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    api.get('/users/certificates').then((res) => {
      setCerts(res.data.certificates || []);
    }).catch(() => {
      setCerts([]);
    }).finally(() => setLoading(false));
  }, []);

  const handleDownload = async (cert) => {
    try {
      const res = await api.get(`/users/certificates/${cert.id}/download`, { responseType: 'blob' });
      const url = window.URL.createObjectURL(new Blob([res.data]));
      const link = document.createElement('a');
      link.href = url;
      link.setAttribute('download', `certificate-${cert.credential_id || cert.id}.pdf`);
      document.body.appendChild(link);
      link.click();
      link.remove();
      window.URL.revokeObjectURL(url);
    } catch {
      toast.error('Download not available yet. Certificate URL: ' + (cert.certificate_url || 'N/A'));
    }
  };

  const handleShare = (cert) => {
    const shareUrl = cert.share_url || `${window.location.origin}/verify/${cert.credential_id}`;
    if (navigator.share) {
      navigator.share({
        title: `Certificate: ${cert.course_title || cert.course}`,
        text: `I completed "${cert.course_title || cert.course}" on EduAI Platform!`,
        url: shareUrl,
      }).catch(() => null);
    } else {
      navigator.clipboard.writeText(shareUrl).then(() => {
        toast.success('Certificate link copied to clipboard!');
      }).catch(() => {
        toast.error('Could not copy link');
      });
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center py-32">
        <Loader2 className="w-8 h-8 text-primary-400 animate-spin" />
      </div>
    );
  }

  return (
    <div className="space-y-6 animate-slide-up">
      <div>
        <h1 className="text-2xl font-bold text-white">{t('nav.certificates')}</h1>
        <p className="text-slate-400 mt-1">Your earned certificates</p>
      </div>

      {certs.length === 0 ? (
        <div className="card text-center py-16">
          <Award className="w-12 h-12 text-slate-600 mx-auto mb-4" />
          <p className="text-slate-400">No certificates yet. Complete a course to earn one!</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
          {certs.map((cert) => (
            <div key={cert.id} className="card hover:border-yellow-500/30 transition-all duration-200 group">
              <div className="h-32 bg-gradient-to-br from-yellow-600/20 to-orange-600/20 border border-yellow-500/20 rounded-xl flex items-center justify-center mb-4 relative overflow-hidden">
                <Award className="w-12 h-12 text-yellow-400" />
                <div className="absolute inset-0 bg-gradient-to-br from-yellow-500/5 to-orange-500/5" />
              </div>
              <h3 className="font-semibold text-white mb-1">{cert.course_title || cert.course}</h3>
              <p className="text-sm text-slate-400 mb-1">{cert.issuer || 'EduAI Platform'}</p>
              <div className="flex items-center gap-1 text-xs text-slate-500 mb-4">
                <Calendar className="w-3.5 h-3.5" />
                <span>{new Date(cert.issued_at || cert.date).toLocaleDateString()}</span>
              </div>
              <p className="text-xs text-slate-500 font-mono mb-4">{cert.credential_id || cert.credentialId}</p>
              <div className="flex gap-2">
                <button
                  onClick={() => handleDownload(cert)}
                  className="flex-1 flex items-center justify-center gap-1.5 py-2 text-xs bg-slate-700 hover:bg-slate-600 text-slate-300 rounded-lg transition-colors"
                >
                  <Download className="w-3.5 h-3.5" />
                  {t('common.download')}
                </button>
                <button
                  onClick={() => handleShare(cert)}
                  className="flex-1 flex items-center justify-center gap-1.5 py-2 text-xs bg-slate-700 hover:bg-slate-600 text-slate-300 rounded-lg transition-colors"
                >
                  <Share2 className="w-3.5 h-3.5" />
                  Share
                </button>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
