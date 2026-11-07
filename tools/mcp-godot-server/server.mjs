import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import net from "net";
import { spawn } from "child_process";

const GODOT_PORT = 7055;
const GODOT_HOST = "127.0.0.1";
const GODOT_EXE = "D:\\GodotProjects\\Godot\\Godot.exe";
const PROJECT_PATH = "D:\\GodotProjects\\BeachFishing2D";

function sendToGodot(action, params = {}) {
  return new Promise((resolve, reject) => {
    const socket = new net.Socket();
    let responseData = "";

    socket.connect(GODOT_PORT, GODOT_HOST, () => {
      socket.write(JSON.stringify({ action, ...params }));
    });

    socket.on("data", (data) => {
      responseData += data.toString();
      if (responseData.includes("\n")) {
        socket.destroy();
        try {
          resolve(JSON.parse(responseData.trim()));
        } catch (e) {
          resolve({ raw: responseData });
        }
      }
    });

    socket.on("error", (err) => {
      socket.destroy();
      reject(new Error("Lỗi kết nối Godot plugin (Port 7055): " + err.message));
    });

    socket.setTimeout(3000, () => {
      socket.destroy();
      reject(new Error("Timeout khi kết nối tới Godot plugin."));
    });
  });
}

function launchGodotProcess(extraArgs = []) {
  return new Promise((resolve, reject) => {
    try {
      const child = spawn(GODOT_EXE, ["--path", PROJECT_PATH, ...extraArgs], {
        detached: true,
        stdio: "ignore",
      });

      child.on("error", (err) => {
        reject(new Error("Không thể khởi chạy Godot.exe: " + err.message));
      });

      child.unref();
      resolve({
        status: "ok",
        message: "Đã gửi lệnh chạy Godot thành công.",
        exe: GODOT_EXE,
        project: PROJECT_PATH,
      });
    } catch (err) {
      reject(err);
    }
  });
}

const server = new Server(
  { name: "godot-mcp-server", version: "1.1.0" },
  { capabilities: { tools: {} } },
);

server.setRequestHandler(ListToolsRequestSchema, async () => {
  return {
    tools: [
      {
        name: "godot_launch",
        description: "Khởi động Godot Editor với dự án BeachFishing2D",
        inputSchema: { type: "object", properties: {} },
      },
      {
        name: "godot_run_project",
        description: "Chạy thử (Play) trực tiếp game BeachFishing2D",
        inputSchema: { type: "object", properties: {} },
      },
      {
        name: "godot_ping",
        description: "Kiểm tra kết nối TCP với Godot Editor đang mở",
        inputSchema: { type: "object", properties: {} },
      },
      {
        name: "godot_rescan_filesystem",
        description:
          "Quét lại Resource FileSystem sau khi AI tạo file script/scene mới",
        inputSchema: { type: "object", properties: {} },
      },
      {
        name: "godot_get_open_scenes",
        description: "Liệt kê danh sách các Scene đang mở trong Godot Editor",
        inputSchema: { type: "object", properties: {} },
      },
    ],
  };
});

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;
  try {
    let result;
    if (name === "godot_launch") {
      result = await launchGodotProcess(["--editor"]);
    } else if (name === "godot_run_project") {
      result = await launchGodotProcess([]);
    } else if (name === "godot_ping") {
      result = await sendToGodot("ping");
    } else if (name === "godot_rescan_filesystem") {
      result = await sendToGodot("rescan_filesystem");
    } else if (name === "godot_get_open_scenes") {
      result = await sendToGodot("get_open_scenes");
    } else {
      throw new Error(`Tool không tồn tại: ${name}`);
    }

    return {
      content: [{ type: "text", text: JSON.stringify(result, null, 2) }],
    };
  } catch (error) {
    return {
      isError: true,
      content: [{ type: "text", text: error.message }],
    };
  }
});

const transport = new StdioServerTransport();
await server.connect(transport);
