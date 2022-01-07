module.exports = {
  "rid": "hello_world",
  "meta": {
    "name": "Hello World",
    "description": "\n  A first ruleset for the Quickstart\n  ",
    "author": "Phil Windley",
    "shares": ["hello"]
  },
  "init": async function ($rsCtx, $mkCtx) {
    const $default = Symbol("default");
    const $ctx = $mkCtx($rsCtx);
    const $stdlib = $ctx.module("stdlib");
    const klog1 = $stdlib["klog"];
    const send_directive1 = $stdlib["send_directive"];
    const __testing1 = {
      "queries": [{
          "name": "hello",
          "args": ["obj"]
        }],
      "events": [
        {
          "domain": "echo",
          "name": "hello",
          "attrs": ["name"]
        },
        {
          "domain": "echo",
          "name": "monkey",
          "attrs": ["name"]
        }
      ]
    };
    const hello2 = $ctx.krl.Function(["obj"], async function (obj3) {
      const msg3 = await $stdlib["+"]($ctx, [
        "Hello ",
        obj3
      ]);
      return msg3;
    });
    const $rs = new $ctx.krl.SelectWhen.SelectWhen();
    $rs.when($ctx.krl.SelectWhen.e("echo:hello"), async function ($event, $state, $last) {
      try {
        $ctx.setCurrentRuleName("hello_world");
        $ctx.log.debug("rule selected", { "rule_name": "hello_world" });
        const $name$3 = await klog1($ctx, [
          await $ctx.krl.assertFunction($ctx.module("event")["attr"])($ctx, ["name"]),
          "our passed in name: "
        ]);
        var $fired = true;
        if ($fired) {
          await send_directive1($ctx, [
            "say",
            { "something": "Hello World" }
          ]);
        }
        if ($fired)
          $ctx.log.debug("fired");
        else
          $ctx.log.debug("not fired");
      } finally {
        $ctx.setCurrentRuleName(null);
      }
    });
    $rs.when($ctx.krl.SelectWhen.e("echo:monkey"), async function ($event, $state, $last) {
      try {
        $ctx.setCurrentRuleName("hello_monkey");
        $ctx.log.debug("rule selected", { "rule_name": "hello_monkey" });
        const $name$3 = await $ctx.krl.assertFunction($ctx.module("event")["attr"])($ctx, ["name"]) ? await $ctx.krl.assertFunction($ctx.module("event")["attr"])($ctx, ["name"]) : "Monkey";
        var $fired = true;
        if ($fired) {
          await send_directive1($ctx, [
            "say",
            {
              "something": await $stdlib["+"]($ctx, [
                "Hello ",
                $name$3
              ])
            }
          ]);
        }
        if ($fired)
          $ctx.log.debug("fired");
        else
          $ctx.log.debug("not fired");
      } finally {
        $ctx.setCurrentRuleName(null);
      }
    });
    return {
      "event": async function (event, eid) {
        $ctx.setEvent(Object.assign({}, event, { "eid": eid }));
        try {
          await $rs.send(event);
        } finally {
          $ctx.setEvent(null);
        }
        return $ctx.drainDirectives();
      },
      "query": {
        "hello": async function (query, qid) {
          $ctx.setQuery(Object.assign({}, query, { "qid": qid }));
          try {
            return await hello2($ctx, query.args);
          } finally {
            $ctx.setQuery(null);
          }
        },
        "__testing": function () {
          return __testing1;
        }
      }
    };
  }
};
//# sourceMappingURL=data:application/json;base64,eyJ2ZXJzaW9uIjozLCJzb3VyY2VzIjpbXSwibmFtZXMiOltdLCJtYXBwaW5ncyI6IiIsInNvdXJjZXNDb250ZW50IjpbXX0=
