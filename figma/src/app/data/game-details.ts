export interface GameDetail {
  id: string;
  title: string;
  console: string;
  consoleFull: string;
  lastPlayed: string;
  progress: number;
  image: string;
  icon: string;
  rating: number;
  totalPlayTime: string;
  description: string;
  releaseYear: number;
  genre: string;
  size: string;
  saveStates: number;
}

export const gameDetailsData: Record<string, GameDetail> = {
  "pokemon-emerald": {
    id: "pokemon-emerald",
    title: "Pokemon Emerald",
    console: "GBA",
    consoleFull: "Game Boy Advance",
    lastPlayed: "Today",
    progress: 75,
    image: "https://images.unsplash.com/photo-1606144042614-b2417e99c4e3?w=800&h=600&fit=crop",
    icon: "🟢",
    rating: 5,
    totalPlayTime: "48h 32m",
    description: "Embark on an epic adventure through the Hoenn region. Catch, train, and battle Pokémon while thwarting the plans of Team Aqua and Team Magma.",
    releaseYear: 2004,
    genre: "RPG / Adventure",
    size: "16.2 MB",
    saveStates: 3,
  },
  "final-fantasy-vii": {
    id: "final-fantasy-vii",
    title: "Final Fantasy VII",
    console: "PS1",
    consoleFull: "PlayStation 1",
    lastPlayed: "Yesterday",
    progress: 45,
    image: "https://images.unsplash.com/photo-1550745165-9bc0b252726f?w=800&h=600&fit=crop",
    icon: "⚔️",
    rating: 5,
    totalPlayTime: "72h 15m",
    description: "Join Cloud Strife and AVALANCHE in their fight against the evil Shinra Corporation. Experience one of the most iconic RPGs of all time.",
    releaseYear: 1997,
    genre: "RPG",
    size: "1.4 GB",
    saveStates: 5,
  },
};
