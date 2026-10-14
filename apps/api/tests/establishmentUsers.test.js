const express = require("express");

jest.mock("../src/config/database", () => ({ query: jest.fn() }));
jest.mock("../src/middleware/auth", () => ({
  authenticateEstablishment: (req, res, next) => next(),
}));

const pool = require("../src/config/database");
const router = require("../src/routes/establishmentUsers");

const ESTABLISHMENT_A = "11111111-1111-4111-8111-111111111111";
const ESTABLISHMENT_B = "22222222-2222-4222-8222-222222222222";
const SUPER_USER = "33333333-3333-4333-8333-333333333333";
const REGULAR_USER = "44444444-4444-4444-8444-444444444444";
const OTHER_USER = "55555555-5555-4555-8555-555555555555";

function routeHandler(path, method) {
  const layer = router.stack.find(
    (entry) => entry.route?.path === path && entry.route.methods[method],
  );
  return layer.route.stack.at(-1).handle;
}

function routeMiddleware(path, method, index = 0) {
  const layer = router.stack.find(
    (entry) => entry.route?.path === path && entry.route.methods[method],
  );
  return layer.route.stack[index].handle;
}

function run(handler, body = {}, params = {}, role = "establishment_super_user") {
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
  const req = {
    body,
    params,
    ip: "127.0.0.1",
    establishment: {
      id: ESTABLISHMENT_A,
      establishment_user_id: SUPER_USER,
      role,
    },
  };
  return Promise.resolve(
    handler(req, res, (error) => {
      throw error;
    }),
  ).then(() => res);
}

describe("establishment user management", () => {
  beforeEach(() => {
    pool.query.mockReset();
  });

  test("lists only users from the authenticated establishment", async () => {
    const handler = routeHandler("/", "get");
    pool.query.mockResolvedValueOnce({ rows: [{ id: REGULAR_USER }] });

    const res = await run(handler);

    expect(res.statusCode).toBe(200);
    expect(res.body.users).toEqual([{ id: REGULAR_USER }]);
    expect(pool.query.mock.calls[0][1]).toEqual([ESTABLISHMENT_A]);
    expect(pool.query.mock.calls[0][0]).toContain(
      "WHERE establishment_id = $1",
    );
  });

  test("creates a Regular User for the authenticated establishment and audits it", async () => {
    const handler = routeHandler("/", "post");
    const created = {
      id: REGULAR_USER,
      email: "cashier@example.com",
      role: "establishment_regular_user",
    };
    pool.query
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [created] })
      .mockResolvedValueOnce({ rows: [] });

    const res = await run(handler, {
      email: "cashier@example.com",
      full_name: "Cashier One",
    });

    expect(res.statusCode).toBe(201);
    expect(res.body.user).toEqual(created);
    expect(pool.query.mock.calls[1][1][0]).toBe(ESTABLISHMENT_A);
    expect(pool.query.mock.calls[1][1][4]).toBe(SUPER_USER);
    expect(pool.query.mock.calls[2][0]).toContain(
      "establishment_user_invited",
    );
  });

  test("does not update a user belonging to another establishment", async () => {
    const handler = routeHandler("/:id/status", "patch");
    pool.query.mockResolvedValueOnce({ rows: [] });

    const res = await run(
      handler,
      { account_status: "inactive" },
      { id: OTHER_USER },
    );

    expect(res.statusCode).toBe(404);
    expect(res.body.error).toBe("Establishment user not found");
    expect(pool.query.mock.calls[0][1]).toEqual([OTHER_USER, ESTABLISHMENT_A]);
    expect(pool.query).toHaveBeenCalledTimes(1);
  });

  test("denies user management to Regular Users", async () => {
    const handler = routeMiddleware("/", "post");
    const res = await run(
      handler,
      {
        email: "another@example.com",
        full_name: "Another User",
      },
      {},
      "establishment_regular_user",
    );

    expect(res.statusCode).toBe(403);
    expect(res.body.error).toContain("Super User");
    expect(pool.query).not.toHaveBeenCalled();
  });

  test("prevents a Super User from changing their own role", async () => {
    const handler = routeHandler("/:id/role", "patch");
    pool.query.mockResolvedValueOnce({
      rows: [{ id: SUPER_USER, role: "establishment_super_user" }],
    });

    const res = await run(
      handler,
      { role: "establishment_regular_user" },
      { id: SUPER_USER },
    );

    expect(res.statusCode).toBe(400);
    expect(res.body.error).toBe("Cannot change your own role");
    expect(pool.query).toHaveBeenCalledTimes(1);
  });
});
