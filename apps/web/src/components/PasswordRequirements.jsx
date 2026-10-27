import { Check, Circle, X } from "lucide-react";
import { PASSWORD_RULES } from "../utils/passwordPolicy";

// Live checklist under a password field. Neutral until the user types,
// then green for each met rule and red for each unmet rule.
export default function PasswordRequirements({ password }) {
  const hasInput = password.length > 0;

  return (
    <ul className="mt-2 space-y-1" aria-label="Password requirements">
      {PASSWORD_RULES.map((rule) => {
        const passed = rule.test(password);
        const color = !hasInput ? "#9ca3af" : passed ? "#16a34a" : "#dc2626";
        const Icon = !hasInput ? Circle : passed ? Check : X;

        return (
          <li
            key={rule.key}
            className="flex items-center gap-1.5 text-xs"
            style={{ color }}
          >
            <Icon className="w-3.5 h-3.5 flex-shrink-0" />
            <span>{rule.label}</span>
          </li>
        );
      })}
    </ul>
  );
}
