import { RouterProvider } from "react-router";
import { IPhoneMockup } from "./components/iphone-mockup";
import { router } from "./routes";
import { ThemeProvider } from "./contexts/theme-context";

export default function App() {
  return (
    <ThemeProvider>
      <IPhoneMockup>
        <RouterProvider router={router} />
      </IPhoneMockup>
    </ThemeProvider>
  );
}