export function AppIcon({ className = "w-full h-full" }: { className?: string }) {
  return (
    <svg
      viewBox="0 0 200 200"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      className={className}
    >
      {/* Background gradient */}
      <defs>
        <linearGradient id="bgGradient" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stopColor="#9333ea" />
          <stop offset="100%" stopColor="#7c3aed" />
        </linearGradient>
        <linearGradient id="lightningGradient" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stopColor="#fbbf24" />
          <stop offset="100%" stopColor="#f59e0b" />
        </linearGradient>
        <filter id="glow">
          <feGaussianBlur stdDeviation="4" result="coloredBlur" />
          <feMerge>
            <feMergeNode in="coloredBlur" />
            <feMergeNode in="SourceGraphic" />
          </feMerge>
        </filter>
      </defs>

      {/* Main background circle */}
      <circle cx="100" cy="100" r="90" fill="url(#bgGradient)" />
      
      {/* Inner dark circle for depth */}
      <circle cx="100" cy="100" r="75" fill="#0a0118" opacity="0.3" />

      {/* Game controller D-pad left */}
      <rect x="50" y="85" width="15" height="30" rx="3" fill="white" opacity="0.9" />
      <rect x="43" y="92" width="29" height="15" rx="3" fill="white" opacity="0.9" />

      {/* Game controller buttons (right side) */}
      <circle cx="135" cy="85" r="8" fill="white" opacity="0.9" />
      <circle cx="155" cy="85" r="8" fill="white" opacity="0.9" />
      <circle cx="135" cy="105" r="8" fill="white" opacity="0.9" />
      <circle cx="155" cy="105" r="8" fill="white" opacity="0.9" />

      {/* Lightning bolt in center */}
      <path
        d="M110 60 L90 95 L105 95 L95 130 L120 90 L105 90 Z"
        fill="url(#lightningGradient)"
        filter="url(#glow)"
      />

      {/* Accent glow rings */}
      <circle
        cx="100"
        cy="100"
        r="85"
        fill="none"
        stroke="white"
        strokeWidth="2"
        opacity="0.2"
      />
      <circle
        cx="100"
        cy="100"
        r="80"
        fill="none"
        stroke="white"
        strokeWidth="1"
        opacity="0.1"
      />
    </svg>
  );
}
