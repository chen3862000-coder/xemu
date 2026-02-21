import { motion } from "motion/react";
import { Header } from "../components/header";
import { EmulatorCard } from "../components/emulator-card";
import { RecentGames } from "../components/recent-games";
import { ImportRomsButton } from "../components/import-roms-button";
import { Gamepad2, TrendingUp } from "lucide-react";
import { useNavigate } from "react-router";

const emulators = [
  {
    name: "Game Boy",
    shortName: "GB",
    gamesCount: 42,
    gradient: "bg-gradient-to-br from-green-500/20 to-green-600/20",
    icon: "🎮",
  },
  {
    name: "Game Boy Color",
    shortName: "GBC",
    gamesCount: 38,
    gradient: "bg-gradient-to-br from-blue-500/20 to-purple-600/20",
    icon: "🎨",
  },
  {
    name: "Game Boy Advance",
    shortName: "GBA",
    gamesCount: 56,
    gradient: "bg-gradient-to-br from-purple-500/20 to-pink-600/20",
    icon: "⚡",
  },
  {
    name: "Nintendo DS",
    shortName: "NDS",
    gamesCount: 31,
    gradient: "bg-gradient-to-br from-cyan-500/20 to-blue-600/20",
    icon: "📱",
  },
  {
    name: "PlayStation 1",
    shortName: "PS1",
    gamesCount: 24,
    gradient: "bg-gradient-to-br from-gray-500/20 to-gray-700/20",
    icon: "💿",
  },
  {
    name: "Nintendo 3DS",
    shortName: "3DS",
    gamesCount: 19,
    gradient: "bg-gradient-to-br from-red-500/20 to-orange-600/20",
    icon: "🔺",
  },
  {
    name: "PlayStation Portable",
    shortName: "PSP",
    gamesCount: 27,
    gradient: "bg-gradient-to-br from-indigo-500/20 to-purple-600/20",
    icon: "🎯",
  },
];

const stats = [
  { label: "Total Games", value: "237", icon: Gamepad2 },
  { label: "Hours Played", value: "1,284", icon: TrendingUp },
];

export default function Home() {
  const navigate = useNavigate();

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

      <Header />

      <main className="relative px-4 py-4 space-y-6">
        {/* Stats section */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5, delay: 0.2 }}
          className="grid grid-cols-2 gap-3"
        >
          {stats.map((stat, index) => (
            <motion.div
              key={stat.label}
              whileHover={{ scale: 1.02, y: -2 }}
              onClick={() => {
                if (stat.label === "Total Games") {
                  navigate("/all-games");
                }
              }}
              className={`relative group overflow-hidden rounded-xl bg-card border border-border/50 p-4 ${
                stat.label === "Total Games" ? "cursor-pointer" : ""
              }`}
            >
              <motion.div
                className="absolute inset-0 bg-gradient-to-br from-primary/10 to-accent/10 opacity-0 group-hover:opacity-100 transition-opacity duration-300"
              />
              <div className="relative flex items-center justify-between">
                <div>
                  <p className="text-xs text-muted-foreground mb-0.5">
                    {stat.label}
                  </p>
                  <motion.p
                    initial={{ scale: 0 }}
                    animate={{ scale: 1 }}
                    transition={{
                      type: "spring",
                      stiffness: 200,
                      delay: 0.3 + index * 0.1,
                    }}
                    className="text-2xl font-bold bg-gradient-to-r from-primary to-accent bg-clip-text text-transparent"
                  >
                    {stat.value}
                  </motion.p>
                </div>
                <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-primary/20 to-accent/20 flex items-center justify-center">
                  <stat.icon className="w-5 h-5 text-primary" />
                </div>
              </div>
            </motion.div>
          ))}
        </motion.div>

        {/* Import ROMs Button */}
        <ImportRomsButton />

        {/* Recent games */}
        <RecentGames />

        {/* Emulators section */}
        <div className="space-y-3">
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ duration: 0.5, delay: 0.4 }}
            className="flex items-center justify-between"
          >
            <div className="flex items-center gap-2">
              <Gamepad2 className="w-4 h-4 text-primary" />
              <h2 className="text-base font-semibold">All Emulators</h2>
            </div>
            <span className="text-xs text-muted-foreground">
              {emulators.length} systems
            </span>
          </motion.div>

          <div className="grid grid-cols-1 gap-3">
            {emulators.map((emulator, index) => (
              <EmulatorCard
                key={emulator.shortName}
                {...emulator}
                index={index}
              />
            ))}
          </div>
        </div>

        {/* Bottom space for scrolling */}
        <div className="h-8" />
      </main>
    </div>
  );
}