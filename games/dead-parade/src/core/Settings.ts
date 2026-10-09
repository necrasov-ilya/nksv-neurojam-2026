// Persistent user settings (localStorage).

export interface SettingsData {
  master: number;
  music: number;
  sfx: number;
  sensitivity: number;
  shadows: boolean | "low" | "medium" | "high";
  hordeQuality: "low" | "medium" | "high";
  fullscreen: boolean;
}

const KEY = "dead-parade-settings-v1";

const DEFAULTS: SettingsData = {
  master: 0.85,
  music: 0.65,
  sfx: 0.9,
  sensitivity: 1,
  shadows: "medium",
  hordeQuality: "high",
  fullscreen: false,
};

export class Settings {
  data: SettingsData = { ...DEFAULTS };

  constructor() {
    try {
      const raw = localStorage.getItem(KEY);
      if (raw) {
        const parsed = JSON.parse(raw) as Partial<SettingsData>;
        if (parsed && typeof parsed === "object" && "master" in parsed) {
          this.data = { ...DEFAULTS, ...parsed };
        }
      }
    } catch {
      // corrupted storage -> keep defaults
    }
  }

  save(): void {
    try {
      localStorage.setItem(KEY, JSON.stringify(this.data));
    } catch {
      // storage unavailable (private mode etc.) — ignore
    }
  }

  get shadowsMapSize(): number {
    if (typeof this.data.shadows === 'boolean') return this.data.shadows ? 1024 : 0;
    return this.data.shadows === "high" ? 2048 : this.data.shadows === "medium" ? 1024 : 0;
  }
}