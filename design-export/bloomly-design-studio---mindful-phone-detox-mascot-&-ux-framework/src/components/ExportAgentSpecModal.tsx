import React, { useState } from 'react';
import { Copy, Check, Download, FileText, X } from 'lucide-react';
import { generateAgentMarkdownSpec } from '../design-system/agent-spec-exporter';

interface ExportAgentSpecModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export const ExportAgentSpecModal: React.FC<ExportAgentSpecModalProps> = ({ isOpen, onClose }) => {
  const [copied, setCopied] = useState(false);
  const specContent = generateAgentMarkdownSpec();

  if (!isOpen) return null;

  const handleCopy = () => {
    navigator.clipboard.writeText(specContent);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const handleDownload = () => {
    const blob = new Blob([specContent], { type: 'text/markdown' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'BLOOMY_DETOX_APP_DESIGN_SPEC.md';
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-stone-900/60 backdrop-blur-sm animate-in fade-in duration-200">
      <div className="bg-white rounded-3xl border border-stone-200 shadow-2xl max-w-3xl w-full max-h-[88vh] flex flex-col overflow-hidden">
        {/* Header */}
        <div className="px-6 py-4 border-b border-stone-100 flex items-center justify-between bg-stone-50/60">
          <div className="flex items-center gap-2.5">
            <div className="p-2 bg-emerald-100 text-emerald-800 rounded-xl">
              <FileText className="w-5 h-5" />
            </div>
            <div>
              <h3 className="text-base font-bold text-stone-900">Developer Agent Implementation Specification</h3>
              <p className="text-xs text-stone-500">
                Ready-to-use markdown prompt & architecture blueprint for your AI coding agent
              </p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="p-1.5 rounded-xl hover:bg-stone-200 text-stone-500 hover:text-stone-800 transition-colors cursor-pointer"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Content Viewer */}
        <div className="flex-1 overflow-y-auto p-6 font-mono text-xs text-stone-700 bg-stone-900 text-stone-200 leading-relaxed select-text">
          <pre className="whitespace-pre-wrap">{specContent}</pre>
        </div>

        {/* Footer Actions */}
        <div className="px-6 py-4 border-t border-stone-100 bg-stone-50 flex items-center justify-between gap-4">
          <span className="text-xs text-stone-500">
            Contains color tokens, SVG mascot anatomy, mood state machines, and copy tables.
          </span>
          <div className="flex items-center gap-3">
            <button
              onClick={handleCopy}
              className="px-4 py-2 bg-stone-100 hover:bg-stone-200 text-stone-800 rounded-xl text-xs font-semibold flex items-center gap-1.5 transition-colors cursor-pointer"
            >
              {copied ? <Check className="w-4 h-4 text-emerald-600" /> : <Copy className="w-4 h-4" />}
              <span>{copied ? 'Copied Prompt!' : 'Copy to Clipboard'}</span>
            </button>
            <button
              onClick={handleDownload}
              className="px-4 py-2 bg-emerald-700 hover:bg-emerald-800 text-white rounded-xl text-xs font-semibold flex items-center gap-1.5 shadow-xs transition-colors cursor-pointer"
            >
              <Download className="w-4 h-4" />
              <span>Download .md File</span>
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};
