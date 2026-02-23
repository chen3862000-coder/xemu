// Track which games have been played
export const playedGamesData = {
  "pokemon-emerald": {
    platform: "GBA",
    lastPlayed: "Today",
    progress: 75,
    totalPlayTime: "48h",
    hasSaveStates: true,
  },
  "final-fantasy-vii": {
    platform: "PS1",
    lastPlayed: "Yesterday",
    progress: 45,
    totalPlayTime: "72h",
    hasSaveStates: true,
  },
};

export function isGamePlayed(gameId: string): boolean {
  return gameId in playedGamesData;
}

export function getPlayedGameData(gameId: string) {
  return playedGamesData[gameId as keyof typeof playedGamesData];
}
