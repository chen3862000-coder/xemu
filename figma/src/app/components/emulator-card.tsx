import { motion } from "motion/react";
import { Play, ChevronRight } from "lucide-react";
import { useNavigate } from "react-router";

interface EmulatorCardProps {
  name: string;
  shortName: string;
  gamesCount: number;
  gradient: string;
  icon: string;
  index: number;
}

export function EmulatorCard({
  name,
  shortName,
  gamesCount,
  gradient,
  icon,
  index,
}: EmulatorCardProps) {
  const navigate = useNavigate();

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.4, delay: index * 0.1 }}
      whileHover={{ scale: 1.02, y: -4 }}
      onClick={() => navigate(`/games/${shortName.toLowerCase()}`)}
      className="relative group cursor-pointer"
    >
      <div className="relative overflow-hidden rounded-xl bg-card border border-border/50 backdrop-blur-sm">
        {/* Gradient background */}
        <div
          className={`absolute inset-0 opacity-20 ${gradient} group-hover:opacity-30 transition-opacity duration-300`}
        />
        
        {/* Glow effect */}
        <motion.div
          className={`absolute -inset-0.5 ${gradient} opacity-0 group-hover:opacity-20 blur-xl transition-opacity duration-300`}
          animate={{
            opacity: [0, 0.2, 0],
          }}
          transition={{
            duration: 2,
            repeat: Infinity,
            repeatType: "reverse",
          }}
        />

        <div className="relative p-4 flex items-center justify-between">
          <div className="flex items-center gap-3">
            {/* Console icon */}
            <motion.div
              whileHover={{ rotate: [0, -10, 10, -10, 0] }}
              transition={{ duration: 0.5 }}
              className="w-12 h-12 rounded-xl bg-gradient-to-br from-primary/20 to-accent/20 border border-primary/30 flex items-center justify-center flex-shrink-0"
            >
              <span className="text-2xl">{icon}</span>
            </motion.div>

            <div>
              <h3 className="text-base font-semibold text-foreground mb-0.5">
                {name}
              </h3>
              <div className="flex items-center gap-1.5">
                <span className="text-xs text-muted-foreground">
                  {shortName}
                </span>
                <span className="text-xs text-muted-foreground">•</span>
                <span className="text-xs text-primary">
                  {gamesCount} games
                </span>
              </div>
            </div>
          </div>

          {/* Action button */}
          <motion.button
            whileHover={{ scale: 1.1 }}
            whileTap={{ scale: 0.95 }}
            className="w-10 h-10 rounded-full bg-primary hover:bg-primary/90 flex items-center justify-center transition-colors shadow-lg shadow-primary/50 flex-shrink-0"
          >
            <Play className="w-4 h-4 text-primary-foreground fill-current ml-0.5" />
          </motion.button>
        </div>
      </div>
    </motion.div>
  );
}