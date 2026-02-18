import { createBrowserRouter } from "react-router";
import Home from "./pages/home";
import Settings from "./pages/settings";
import GameList from "./pages/game-list";
import GameDetail from "./pages/game-detail";

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
]);