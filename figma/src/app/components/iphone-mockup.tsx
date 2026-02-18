import { ReactNode } from "react";

interface IPhoneMockupProps {
  children: ReactNode;
}

export function IPhoneMockup({ children }: IPhoneMockupProps) {
  return (
    <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-slate-900 via-purple-900 to-slate-900 p-8">
      {/* iPhone frame */}
      <div className="relative">
        {/* iPhone body */}
        <div className="relative w-[390px] h-[844px] bg-black rounded-[60px] shadow-2xl border-[14px] border-slate-900 overflow-hidden">
          {/* Notch */}
          <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[150px] h-[30px] bg-black rounded-b-3xl z-50" />
          
          {/* Screen content */}
          <div className="w-full h-full overflow-y-auto bg-background">
            {children}
          </div>
        </div>

        {/* Side buttons */}
        <div className="absolute -left-[3px] top-[120px] w-[3px] h-[30px] bg-slate-800 rounded-l" />
        <div className="absolute -left-[3px] top-[170px] w-[3px] h-[60px] bg-slate-800 rounded-l" />
        <div className="absolute -left-[3px] top-[240px] w-[3px] h-[60px] bg-slate-800 rounded-l" />
        <div className="absolute -right-[3px] top-[200px] w-[3px] h-[80px] bg-slate-800 rounded-r" />
      </div>
    </div>
  );
}
