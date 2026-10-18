import { useState } from "react";
import { Eye, EyeOff } from "lucide-react";

// Renders an input plus an eye toggle. Place it inside a `relative` wrapper.
export default function PasswordInput({ className = "", ...props }) {
  const [show, setShow] = useState(false);
  return (
    <>
      <input
        {...props}
        type={show ? "text" : "password"}
        className={`${className} pr-10`}
      />
      <button
        type="button"
        tabIndex={-1}
        onClick={() => setShow((v) => !v)}
        aria-label={show ? "Hide password" : "Show password"}
        className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600"
      >
        {show ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
      </button>
    </>
  );
}
