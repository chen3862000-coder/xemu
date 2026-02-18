import { motion } from "motion/react";
import { ChevronRight, LucideIcon } from "lucide-react";

interface SettingsItemProps {
  icon: LucideIcon;
  title: string;
  description: string;
  iconColor: string;
  iconBg: string;
  index: number;
  onClick?: () => void;
}

export function SettingsItem({
  icon: Icon,
  title,
  description,
  iconColor,
  iconBg,
  index,
  onClick,
}: SettingsItemProps) {
  return (
    <motion.div
      initial={{ opacity: 0, x: -20 }}
      animate={{ opacity: 1, x: 0 }}
      transition={{ duration: 0.4, delay: index * 0.1 }}
      whileHover={{ scale: 1.02, x: 4 }}
      whileTap={{ scale: 0.98 }}
      onClick={onClick}
      className="relative group cursor-pointer"
    >
      <div className="relative overflow-hidden rounded-xl bg-card border border-border/50 backdrop-blur-sm">
        {/* Glow effect on hover */}
        <motion.div
          className="absolute inset-0 bg-gradient-to-r from-primary/10 to-accent/10 opacity-0 group-hover:opacity-100 transition-opacity duration-300"
        />

        <div className="relative p-4 flex items-center justify-between">
          <div className="flex items-center gap-3">
            {/* Icon */}
            <motion.div
              whileHover={{ rotate: [0, -10, 10, -10, 0] }}
              transition={{ duration: 0.5 }}
              className={`w-12 h-12 rounded-xl ${iconBg} flex items-center justify-center flex-shrink-0`}
            >
              <Icon className={`w-6 h-6 ${iconColor}`} />
            </motion.div>

            <div>
              <h3 className="text-base font-semibold text-foreground mb-0.5">
                {title}
              </h3>
              <p className="text-xs text-muted-foreground">
                {description}
              </p>
            </div>
          </div>

          {/* Arrow */}
          <motion.div
            className="w-6 h-6 flex items-center justify-center opacity-50 group-hover:opacity-100 transition-opacity"
            whileHover={{ x: 4 }}
          >
            <ChevronRight className="w-5 h-5 text-foreground" />
          </motion.div>
        </div>
      </div>
    </motion.div>
  );
}
