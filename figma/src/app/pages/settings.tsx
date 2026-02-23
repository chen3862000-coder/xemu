import { motion } from "motion/react";
import { SettingsHeader } from "../components/settings-header";
import { SettingsItem } from "../components/settings-item";
import { Crown, Share2, MessageSquare, HelpCircle, Moon, Sun } from "lucide-react";
import { AppIcon } from "../components/app-icon";
import { useTheme } from "../contexts/theme-context";

const settingsOptions = [
  {
    icon: Crown,
    title: "Upgrade",
    description: "Unlock premium features",
    iconColor: "text-yellow-500",
    iconBg: "bg-yellow-500/20",
  },
  {
    icon: Share2,
    title: "Share",
    description: "Share XEmu with friends",
    iconColor: "text-blue-500",
    iconBg: "bg-blue-500/20",
  },
  {
    icon: MessageSquare,
    title: "Feedback",
    description: "Send us your thoughts",
    iconColor: "text-green-500",
    iconBg: "bg-green-500/20",
  },
  {
    icon: HelpCircle,
    title: "Support",
    description: "Get help and answers",
    iconColor: "text-purple-500",
    iconBg: "bg-purple-500/20",
  },
];

export default function Settings() {
  const { theme, toggleTheme } = useTheme();

  return (
    <div className="min-h-full bg-background">
      {/* Animated background effect */}
      <div className="fixed inset-0 overflow-hidden pointer-events-none">
        <motion.div
          animate={{
            opacity: [0.03, 0.08, 0.03],
            scale: [1, 1.2, 1],
          }}
          transition={{
            duration: 10,
            repeat: Infinity,
            repeatType: "reverse",
          }}
          className="absolute -top-1/2 -right-1/2 w-full h-full bg-gradient-to-br from-primary to-accent rounded-full blur-3xl"
        />
        <motion.div
          animate={{
            opacity: [0.03, 0.08, 0.03],
            scale: [1.2, 1, 1.2],
          }}
          transition={{
            duration: 8,
            repeat: Infinity,
            repeatType: "reverse",
          }}
          className="absolute -bottom-1/2 -left-1/2 w-full h-full bg-gradient-to-tr from-accent to-primary rounded-full blur-3xl"
        />
      </div>

      <SettingsHeader />

      <main className="relative px-4 py-6 space-y-4">
        {/* App info card */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5, delay: 0.2 }}
          className="relative overflow-hidden rounded-2xl bg-gradient-to-br from-primary/20 via-accent/20 to-primary/20 border border-border/50 p-6 text-center"
        >
          <div className="relative">
            <motion.div
              animate={{
                rotate: 360,
              }}
              transition={{
                duration: 20,
                repeat: Infinity,
                ease: "linear",
              }}
              className="w-20 h-20 mx-auto mb-4 rounded-2xl bg-gradient-to-br from-primary to-accent flex items-center justify-center shadow-2xl shadow-primary/50 p-3"
            >
              <AppIcon />
            </motion.div>
            <h2 className="text-xl font-bold text-foreground mb-1">
              XEmu Pro
            </h2>
            <p className="text-sm text-muted-foreground mb-3">
              Version 2.4.0
            </p>
            <div className="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-background/50 backdrop-blur-sm border border-border/50">
              <div className="w-2 h-2 rounded-full bg-green-500 animate-pulse" />
              <span className="text-xs text-foreground font-medium">
                Free Plan
              </span>
            </div>
          </div>
        </motion.div>

        {/* Theme toggle card */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5, delay: 0.3 }}
          className="bg-card border border-border/50 rounded-xl p-4"
        >
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className={`w-10 h-10 rounded-lg flex items-center justify-center ${
                theme === "light" 
                  ? "bg-amber-500/20" 
                  : "bg-indigo-500/20"
              }`}>
                {theme === "light" ? (
                  <Sun className="w-5 h-5 text-amber-500" />
                ) : (
                  <Moon className="w-5 h-5 text-indigo-400" />
                )}
              </div>
              <div>
                <h3 className="text-sm font-semibold text-foreground">
                  Appearance
                </h3>
                <p className="text-xs text-muted-foreground">
                  {theme === "light" ? "Light Mode" : "Dark Mode"}
                </p>
              </div>
            </div>
            
            {/* Theme toggle button */}
            <motion.button
              onClick={toggleTheme}
              whileTap={{ scale: 0.95 }}
              className={`relative w-14 h-8 rounded-full transition-colors ${
                theme === "light"
                  ? "bg-amber-500"
                  : "bg-indigo-500"
              }`}
            >
              <motion.div
                animate={{
                  x: theme === "light" ? 24 : 2,
                }}
                transition={{
                  type: "spring",
                  stiffness: 500,
                  damping: 30,
                }}
                className="absolute top-1 w-6 h-6 rounded-full bg-white shadow-lg flex items-center justify-center"
              >
                {theme === "light" ? (
                  <Sun className="w-3 h-3 text-amber-500" />
                ) : (
                  <Moon className="w-3 h-3 text-indigo-500" />
                )}
              </motion.div>
            </motion.button>
          </div>
        </motion.div>

        {/* Settings options */}
        <div className="space-y-3">
          {settingsOptions.map((option, index) => (
            <SettingsItem
              key={option.title}
              {...option}
              index={index}
              onClick={() => {
                // Handle click action
                console.log(`${option.title} clicked`);
              }}
            />
          ))}
        </div>

        {/* App info footer */}
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ duration: 0.5, delay: 0.6 }}
          className="pt-6 pb-8 text-center space-y-2"
        >
          <p className="text-xs text-muted-foreground">
            Made with ❤️ for retro gamers
          </p>
          <div className="flex items-center justify-center gap-4 text-xs text-muted-foreground">
            <button className="hover:text-primary transition-colors">
              Privacy Policy
            </button>
            <span>•</span>
            <button className="hover:text-primary transition-colors">
              Terms of Service
            </button>
          </div>
        </motion.div>
      </main>
    </div>
  );
}