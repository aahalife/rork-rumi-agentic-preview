import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { Onboarding } from "../sano/screens/Onboarding";

const store = vi.hoisted(() => ({
  scheme: "day", musicOn: false, pathway: "metabolic", tonePreference: "Straight talk",
  setMusicOn: vi.fn(), setEpsilonConsent: vi.fn(), completeOnboarding: vi.fn(), setTab: vi.fn(),
}));
vi.mock("../sano/store", () => ({ useSano: () => store }));
vi.mock("../sano/sound", () => ({ SoundEngine: { playBed: vi.fn() } }));
vi.mock("../sano/ui/Orb", () => ({ Orb: () => <div aria-label="Rumi companion" /> }));

afterEach(cleanup);
beforeEach(() => vi.clearAllMocks());

describe("streamlined onboarding", () => {
  it("reaches home directly from the connection step without interviews or false imports", () => {
    render(<Onboarding />);
    fireEvent.click(screen.getByRole("button", { name: "Get started" }));
    expect(screen.getByRole("button", { name: "Connect my records" })).toBeInTheDocument();
    expect(screen.queryByRole("textbox")).not.toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "Explore the demo for now" }));
    expect(store.completeOnboarding).toHaveBeenCalledWith(expect.objectContaining({ connectedSystems: [], healthConnected: false, values: "", barrier: "" }));
    expect(store.setEpsilonConsent).toHaveBeenCalledWith(false);
    expect(store.setTab).toHaveBeenCalledWith("today");
  });

  it("does not mark a source connected when authorization is unavailable", () => {
    render(<Onboarding />);
    fireEvent.click(screen.getByRole("button", { name: "Get started" }));
    fireEvent.click(screen.getByRole("button", { name: "Connect my records" }));
    expect(screen.getByRole("status")).toHaveTextContent("Records connection isn’t enabled yet");
    expect(store.completeOnboarding).not.toHaveBeenCalled();
    fireEvent.click(screen.getByRole("button", { name: "Back to introduction" }));
    expect(screen.getByRole("button", { name: "Get started" })).toBeInTheDocument();
  });
});
