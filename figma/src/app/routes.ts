import { createBrowserRouter } from "react-router";
import Home from "./pages/home";
import Settings from "./pages/settings";
import GameList from "./pages/game-list";
import GameDetail from "./pages/game-detail";
import PlayedGames from "./pages/played-games";
import AllGames from "./pages/all-games";
import GamePlay from "./pages/game-play";

export const router = createBrowserRouter([
  {
    path: "/",
    Component: Home,
  },
  {
    path: "/settings",
    Component: Settings,
  },
  {
    path: "/games/:platform",
    Component: GameList,
  },
  {
    path: "/game/:gameId",
    Component: GameDetail,
  },
  {
    path: "/played-games",
    Component: PlayedGames,
  },
  {
    path: "/all-games",
    Component: AllGames,
  },
  {
    path: "/play/:platform/:gameId",
    Component: GamePlay,
  },
]);