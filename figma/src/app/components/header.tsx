import { motion } from "motion/react";
import { Search, Settings, User, Zap } from "lucide-react";
import { useNavigate } from "react-router";

export function Header() {
  const navigate = useNavigate();

  return (
    <motion.header
      initial={{ opacity: 0, y: -20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.5 }}
      className="sticky top-0 z-50 backdrop-blur-xl bg-background/80 border-b border-border/50"
    >
      <div className="px-4 py-3 pt-8">
        <div className="flex items-center justify-between">
          {/* Logo and title */}
          <div className="flex items-center gap-2">
            <motion.div
              whileHover={{ rotate: 360 }}
              transition={{ duration: 0.6 }}
              className="w-9 h-9 rounded-xl bg-gradient-to-br from-primary to-accent flex items-center justify-center shadow-lg shadow-primary/50"
            >
              <Zap className="w-5 h-5 text-white" />
            </motion.div>
            <div>
              <h1 className="text-lg font-bold bg-gradient-to-r from-primary via-accent to-primary bg-clip-text text-transparent">
                XEmu
              </h1>
              <p className="text-[10px] text-muted-foreground">
                Classic Gaming Hub
              </p>
            </div>
          </div>

          {/* Actions */}
          <div className="flex items-center gap-2">
            {/* Search */}
            <motion.button
              whileHover={{ scale: 1.05 }}
              whileTap={{ scale: 0.95 }}
              className="w-8 h-8 rounded-full bg-muted/50 hover:bg-muted flex items-center justify-center transition-colors"
            >
              <Search className="w-4 h-4 text-foreground" />
            </motion.button>

            {/* Settings */}
            <motion.button
              onClick={() => navigate("/settings")}
              whileHover={{ scale: 1.05, rotate: 90 }}
              whileTap={{ scale: 0.95 }}
              className="w-8 h-8 rounded-full bg-muted/50 hover:bg-muted flex items-center justify-center transition-colors"
            >
              <Settings className="w-4 h-4 text-foreground" />
            </motion.button>
          </div>
        </div>
      </div>
    </motion.header>
  );
}