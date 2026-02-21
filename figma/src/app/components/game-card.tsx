import { motion } from "motion/react";
import { Play, Star, Clock } from "lucide-react";
import { useNavigate, useParams } from "react-router";

interface GameCardProps {
  name: string;
  coverImage: string;
  rating: number;
  lastPlayed?: string;
  playTime?: string;
  index: number;
}

export function GameCard({
  name,
  coverImage,
  rating,
  lastPlayed,
  playTime,
  index,
}: GameCardProps) {
  const navigate = useNavigate();
  const { platform } = useParams<{ platform: string }>();

  const handleClick = () => {
    const gameIdSlug = name.toLowerCase().replace(/\s+/g, "-").replace(/[^a-z0-9-]/g, "");
    navigate(`/play/${platform}/${gameIdSlug}`);
  };

  return (
    <motion.div
      initial={{ opacity: 0, scale: 0.9 }}
      animate={{ opacity: 1, scale: 1 }}
      transition={{ duration: 0.3, delay: index * 0.05 }}
      whileHover={{ scale: 1.02, y: -4 }}
      whileTap={{ scale: 0.98 }}
      onClick={handleClick}
      className="relative group cursor-pointer"
    >
      <div className="relative overflow-hidden rounded-xl bg-card border border-border/50 backdrop-blur-sm">
        {/* Glow effect on hover */}
        <motion.div className="absolute inset-0 bg-gradient-to-br from-primary/20 to-accent/20 opacity-0 group-hover:opacity-100 transition-opacity duration-300" />

        <div className="relative p-3 flex items-center gap-3">
          {/* Game cover */}
          <motion.div
            whileHover={{ rotate: [0, -2, 2, -2, 0] }}
            transition={{ duration: 0.5 }}
            className="relative w-16 h-16 rounded-lg overflow-hidden flex-shrink-0 bg-gradient-to-br from-primary/20 to-accent/20"
          >
            <div className="absolute inset-0 flex items-center justify-center text-2xl">
              {coverImage}
            </div>
            {/* Play overlay */}
            <motion.div
              initial={{ opacity: 0 }}
              whileHover={{ opacity: 1 }}
              className="absolute inset-0 bg-black/60 flex items-center justify-center"
            >
              <Play className="w-6 h-6 text-white fill-white" />
            </motion.div>
          </motion.div>

          {/* Game info */}
          <div className="flex-1 min-w-0">
            <h3 className="text-sm font-semibold text-foreground mb-1 truncate">
              {name}
            </h3>
            
            {/* Rating */}
            <div className="flex items-center gap-1 mb-1">
              {[...Array(5)].map((_, i) => (
                <Star
                  key={i}
                  className={`w-3 h-3 ${
                    i < rating
                      ? "text-yellow-500 fill-yellow-500"
                      : "text-muted-foreground/30"
                  }`}
                />
              ))}
            </div>

            {/* Meta info */}
            <div className="flex items-center gap-3 text-xs text-muted-foreground">
              {playTime && (
                <div className="flex items-center gap-1">
                  <Clock className="w-3 h-3" />
                  <span>{playTime}</span>
                </div>
              )}
              {lastPlayed && (
                <span className="text-[10px]">{lastPlayed}</span>
              )}
            </div>
          </div>

          {/* Arrow indicator */}
          <motion.div
            className="w-8 h-8 rounded-lg bg-gradient-to-br from-primary/20 to-accent/20 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity"
            whileHover={{ x: 2 }}
          >
            <Play className="w-4 h-4 text-primary fill-primary" />
          </motion.div>
        </div>
      </div>
    </motion.div>
  );
}