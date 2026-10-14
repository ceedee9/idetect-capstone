const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");

jest.mock("../src/config/database", () => ({ query: jest.fn() }));
jest.mock("../src/services/smsService", () => ({
  sendOtp: jest.fn(),
  sendSms: jest.fn(),
}));

const pool = require("../src/config/database");
const router = require("../src/routes/auth");

const loginHandler = router.stack.find(
  (layer) =>
    layer.route?.path === "/establishment/login" &&
    layer.route.methods.post,
).route.stack.at(-1).handle;

function run(body) {
  const res = {
    statusCode: 200,
    body: null,
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(value) {
      this.body = value;
      return this;
    },
  };

  return loginHandler(
    { body, ip: "127.0.0.1" },
    res,
    (error) => {
      throw error;
    },
  ).then(() => res);
}

describe("establishment user-compatible login", () => {
  beforeEach(() => {
    process.env.JWT_SECRET_ESTABLISHMENT = "test-secret";
    process.env.JWT_EXPIRES_IN = "1h";
    pool.query.mockReset();
  });

  test("allows a migrated regular user to sign in to its establishment", async () => {
    const passwordHash = await bcrypt.hash("password-123", 4);
    pool.query
      .mockResolvedValueOnce({
        rows: [
          {
            id: "establishment-1",
            email: "owner@example.com",
            user_email: "cashier@example.com",
            password_hash: "legacy-hash",
            user_password_hash: passwordHash,
            establishment_user_id: "est-user-1",
            user_full_name: "Cashier One",
            user_role: "establishment_regular_user",
            user_account_status: "active",
            user_failed_attempts: 0,
            user_locked_until: null,
            password_reset_required: false,
            status: "approved",
            business_name: "Example Store",
            owner_name: "Owner",
            contact_number: null,
          },
        ],
      })
      .mockResolvedValue({});

    const res = await run({
      email: "cashier@example.com",
      password: "password-123",
    });

    expect(res.statusCode).toBe(200);
    expect(res.body.user.id).toBe("est-user-1");
    expect(res.body.user.email).toBe("cashier@example.com");
    expect(res.body.user.role).toBe("establishment_regular_user");
    expect(res.body.establishment.user_id).toBe("est-user-1");

    const claims = jwt.verify(
      res.body.token,
      process.env.JWT_SECRET_ESTABLISHMENT,
    );
    expect(claims.id).toBe("establishment-1");
    expect(claims.establishment_user_id).toBe("est-user-1");
    expect(claims.role).toBe("establishment_regular_user");
  });
});
