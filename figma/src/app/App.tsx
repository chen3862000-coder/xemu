import { RouterProvider } from "react-router";
import { IPhoneMockup } from "./components/iphone-mockup";
import { router } from "./routes";

export default function App() {
  return (
    <IPhoneMockup>
      <RouterProvider router={router} />
    </IPhoneMockup>
  );
}
