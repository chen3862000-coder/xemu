import { motion } from "motion/react";
import { Upload, FolderOpen, Plus } from "lucide-react";

export function ImportRomsButton() {
  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.5, delay: 0.3 }}
      whileHover={{ scale: 1.02, y: -2 }}
      whileTap={{ scale: 0.98 }}
      className="relative group cursor-pointer overflow-hidden rounded-xl bg-gradient-to-r from-primary to-accent p-[2px]"
    >
      {/* Animated glow effect */}
      <motion.div
        animate={{
          opacity: [0.5, 1, 0.5],
        }}
        transition={{
          duration: 2,
          repeat: Infinity,
          repeatType: "reverse",
        }}
        className="absolute inset-0 bg-gradient-to-r from-primary via-accent to-primary blur-lg"
      />

      <div className="relative bg-card rounded-[10px] p-4">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            {/* Icon */}
            <motion.div
              animate={{
                y: [0, -4, 0],
              }}
              transition={{
                duration: 2,
                repeat: Infinity,
                repeatType: "reverse",
              }}
              className="w-12 h-12 rounded-xl bg-gradient-to-br from-primary to-accent flex items-center justify-center shadow-lg shadow-primary/50"
            >
              <Upload className="w-6 h-6 text-white" />
            </motion.div>

            <div>
              <h3 className="text-base font-semibold text-foreground mb-0.5">
                Import ROMs
              </h3>
              <p className="text-xs text-muted-foreground">
                Add your game files
              </p>
            </div>
          </div>

          {/* Arrow/Plus icon */}
          <motion.div
            whileHover={{ rotate: 90 }}
            transition={{ duration: 0.3 }}
            className="w-8 h-8 rounded-full bg-primary/20 flex items-center justify-center"
          >
            <Plus className="w-5 h-5 text-primary" />
          </motion.div>
        </div>
      </div>
    </motion.div>
  );
}
