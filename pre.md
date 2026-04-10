# DeerFlow 项目代码分析

## 1. 项目整体架构

DeerFlow 是一个基于 LangGraph 的 AI 代理系统，包含前端和后端两部分，提供了完整的 AI 代理交互能力。

### 1.1 目录结构

```
├── backend/            # 后端代码
│   ├── app/            # API 网关和核心应用
│   ├── packages/       # 核心功能模块
│   └── docs/           # 文档
├── frontend/           # 前端代码
│   ├── public/         # 静态资源
│   └── src/            # 前端源码
└── docker/             # Docker 配置
```

## 2. 后端系统

### 2.1 API 网关

API 网关基于 FastAPI 实现，提供了以下主要功能：

- 模型管理（models）
- MCP 配置管理（mcp）
- 内存管理（memory）
- 技能管理（skills）
- 工件管理（artifacts）
- 上传管理（uploads）
- 线程管理（threads）
- 代理管理（agents）
- 建议生成（suggestions）
- 通道管理（channels）

**核心文件**：`backend/app/gateway/app.py`

```python
def create_app() -> FastAPI:
    """创建和配置 FastAPI 应用"""
    app = FastAPI(
        title="DeerFlow API Gateway",
        description="API Gateway for DeerFlow - A LangGraph-based AI agent backend with sandbox execution capabilities.",
        version="0.1.0",
        lifespan=lifespan,
        docs_url="/docs",
        redoc_url="/redoc",
        openapi_url="/openapi.json",
        openapi_tags=[...]
    )
    
    # 包含各种路由
    app.include_router(models.router)
    app.include_router(mcp.router)
    app.include_router(memory.router)
    app.include_router(skills.router)
    app.include_router(artifacts.router)
    app.include_router(uploads.router)
    app.include_router(threads.router)
    app.include_router(agents.router)
    app.include_router(suggestions.router)
    app.include_router(channels.router)
    app.include_router(assistants_compat.router)
    app.include_router(thread_runs.router)
    app.include_router(runs.router)
    
    @app.get("/health", tags=["health"])
    async def health_check() -> dict:
        """健康检查端点"""
        return {"status": "healthy", "service": "deer-flow-gateway"}
    
    return app
```

### 2.2 代理系统

代理系统是 DeerFlow 的核心，基于 LangGraph 实现，提供了以下功能：

- 代理创建和管理
- 中间件系统
- 工具集成
- 状态管理

**核心文件**：`backend/packages/harness/deerflow/agents/factory.py`

```python
def create_deerflow_agent(
    model: BaseChatModel,
    tools: list[BaseTool] | None = None,
    *, 
    system_prompt: str | None = None,
    middleware: list[AgentMiddleware] | None = None,
    features: RuntimeFeatures | None = None,
    extra_middleware: list[AgentMiddleware] | None = None,
    plan_mode: bool = False,
    state_schema: type | None = None,
    checkpointer: BaseCheckpointSaver | None = None,
    name: str = "default",
) -> CompiledStateGraph:
    """从纯 Python 参数创建 DeerFlow 代理"""
    if middleware is not None and features is not None:
        raise ValueError("Cannot specify both 'middleware' and 'features'. Use one or the other.")
    if middleware is not None and extra_middleware:
        raise ValueError("Cannot use 'extra_middleware' with 'middleware' (full takeover).")
    
    effective_tools: list[BaseTool] = list(tools or [])
    effective_state = state_schema or ThreadState
    
    if middleware is not None:
        effective_middleware = list(middleware)
    else:
        feat = features or RuntimeFeatures()
        effective_middleware, extra_tools = _assemble_from_features(
            feat,
            name=name,
            plan_mode=plan_mode,
            extra_middleware=extra_middleware or [],
        )
        # 去重工具，用户提供的工具优先
        existing_names = {t.name for t in effective_tools}
        for t in extra_tools:
            if t.name not in existing_names:
                effective_tools.append(t)
                existing_names.add(t.name)
    
    return create_agent(
        model=model,
        tools=effective_tools or None,
        middleware=effective_middleware,
        system_prompt=system_prompt,
        state_schema=effective_state,
        checkpointer=checkpointer,
        name=name,
    )
```

### 2.3 中间件系统

中间件系统提供了各种功能增强，包括：

- 沙箱基础设施（ThreadData → Uploads → Sandbox）
- 悬垂工具调用处理（DanglingToolCallMiddleware）
- 护栏（GuardrailMiddleware）
- 工具错误处理（ToolErrorHandlingMiddleware）
- 摘要生成（SummarizationMiddleware）
- 任务管理（TodoMiddleware）
- 自动标题生成（TitleMiddleware）
- 内存管理（MemoryMiddleware）
- 图像查看（ViewImageMiddleware）
- 子代理限制（SubagentLimitMiddleware）
- 循环检测（LoopDetectionMiddleware）
- 澄清（ClarificationMiddleware）

### 2.4 存储系统

存储系统基于 SQLite 实现，提供了以下功能：

- 线程数据存储
- 检查点保存
- 状态持久化

### 2.5 通道系统

通道系统支持与外部即时通讯平台的集成，包括：

- 飞书（Feishu）
- Slack
- Telegram
- 企业微信（Wecom）

## 3. 前端系统

### 3.1 前端架构

前端基于 Next.js 实现，采用了以下技术栈：

- React
- TypeScript
- Tailwind CSS
- shadcn/ui

### 3.2 主要页面

#### 3.2.1 着陆页

**文件**：`frontend/src/app/page.tsx`

```tsx
export default function LandingPage() {
  return (
    <div className="min-h-screen w-full bg-[#0a0a0a]">
      <Header />
      <main className="flex w-full flex-col">
        <Hero />
        <CaseStudySection />
        <SkillsSection />
        <SandboxSection />
        <WhatsNewSection />
        <CommunitySection />
      </main>
      <Footer />
    </div>
  );
}
```

#### 3.2.2 工作区页面

**文件**：`frontend/src/app/workspace/page.tsx`

```tsx
export default function WorkspacePage() {
  if (env.NEXT_PUBLIC_STATIC_WEBSITE_ONLY === "true") {
    const firstThread = fs
      .readdirSync(path.resolve(process.cwd(), "public/demo/threads"), {
        withFileTypes: true,
      })
      .find((thread) => thread.isDirectory() && !thread.name.startsWith("."));
    if (firstThread) {
      return redirect(`/workspace/chats/${firstThread.name}`);
    }
  }
  return redirect("/workspace/chats/new");
}
```

#### 3.2.3 聊天页面

**文件**：`frontend/src/app/workspace/chats/[thread_id]/page.tsx`

```tsx
export default function ChatPage() {
  const { t } = useI18n();
  const [showFollowups, setShowFollowups] = useState(false);
  const { threadId, setThreadId, isNewThread, setIsNewThread, isMock } =
    useThreadChat();
  const [settings, setSettings] = useThreadSettings(threadId);
  const [mounted, setMounted] = useState(false);
  useSpecificChatMode();

  useEffect(() => {
    setMounted(true);
  }, []);

  const { showNotification } = useNotification();

  const [thread, sendMessage, isUploading] = useThreadStream({
    threadId: isNewThread ? undefined : threadId,
    context: settings.context,
    isMock,
    onStart: (createdThreadId) => {
      setThreadId(createdThreadId);
      setIsNewThread(false);
      history.replaceState(null, "", `/workspace/chats/${createdThreadId}`);
    },
    onFinish: (state) => {
      if (document.hidden || !document.hasFocus()) {
        let body = "Conversation finished";
        const lastMessage = state.messages.at(-1);
        if (lastMessage) {
          const textContent = textOfMessage(lastMessage);
          if (textContent) {
            body = textContent.length > 200 ? textContent.substring(0, 200) + "..." : textContent;
          }
        }
        showNotification(state.title, { body });
      }
    },
  });

  const handleSubmit = useCallback(
    (message: PromptInputMessage) => {
      void sendMessage(threadId, message);
    },
    [sendMessage, threadId],
  );
  const handleStop = useCallback(async () => {
    await thread.stop();
  }, [thread]);

  return (
    <ThreadContext.Provider value={{ thread, isMock }}>
      <ChatBox threadId={threadId}>
        <div className="relative flex size-full min-h-0 justify-between">
          <header className={cn("absolute top-0 right-0 left-0 z-30 flex h-12 shrink-0 items-center px-4", isNewThread ? "bg-background/0 backdrop-blur-none" : "bg-background/80 shadow-xs backdrop-blur")}>
            <div className="flex w-full items-center text-sm font-medium">
              <ThreadTitle threadId={threadId} thread={thread} />
            </div>
            <div className="flex items-center gap-2">
              <TokenUsageIndicator messages={thread.messages} />
              <ExportTrigger threadId={threadId} />
              <ArtifactTrigger />
            </div>
          </header>
          <main className="flex min-h-0 max-w-full grow flex-col">
            <div className="flex size-full justify-center">
              <MessageList className={cn("size-full", !isNewThread && "pt-10")} threadId={threadId} thread={thread} paddingBottom={messageListPaddingBottom} />
            </div>
            <div className="absolute right-0 bottom-0 left-0 z-30 flex justify-center px-4">
              <div className={cn("relative w-full", isNewThread && "-translate-y-[calc(50vh-96px)]", isNewThread ? "max-w-(--container-width-sm)" : "max-w-(--container-width-md)")}>
                <div className="absolute -top-4 right-0 left-0 z-0">
                  <div className="absolute right-0 bottom-0 left-0">
                    <TodoList className="bg-background/5" todos={thread.values.todos ?? []} hidden={!thread.values.todos || thread.values.todos.length === 0} />
                  </div>
                </div>
                {mounted ? (
                  <InputBox
                    className={cn("bg-background/5 w-full -translate-y-4")}
                    isNewThread={isNewThread}
                    threadId={threadId}
                    autoFocus={isNewThread}
                    status={thread.error ? "error" : thread.isLoading ? "streaming" : "ready"}
                    context={settings.context}
                    extraHeader={isNewThread && <Welcome mode={settings.context.mode} />}
                    disabled={env.NEXT_PUBLIC_STATIC_WEBSITE_ONLY === "true" || isUploading}
                    onContextChange={(context) => setSettings("context", context)}
                    onFollowupsVisibilityChange={setShowFollowups}
                    onSubmit={handleSubmit}
                    onStop={handleStop}
                  />
                ) : (
                  <div aria-hidden="true" className={cn("bg-background/5 h-32 w-full -translate-y-4 rounded-2xl border")} />
                )}
              </div>
            </div>
          </main>
        </div>
      </ChatBox>
    </ThreadContext.Provider>
  );
}
```

### 3.3 核心组件

#### 3.3.1 消息列表（MessageList）

显示聊天消息历史，支持各种类型的消息（文本、代码、图像等）。

#### 3.3.2 输入框（InputBox）

提供用户输入界面，支持文本输入、文件上传等功能。

#### 3.3.3 任务列表（TodoList）

显示和管理任务列表，用于跟踪复杂任务的进度。

#### 3.3.4 代理卡片（AgentCard）

显示代理信息和状态。

## 4. 前后端交互

### 4.1 API 端点

后端提供了以下主要 API 端点：

| 端点 | 功能 | 方法 |
|------|------|------|
| `/api/models` | 模型管理 | GET |
| `/api/mcp` | MCP 配置管理 | GET, POST |
| `/api/memory` | 内存管理 | GET, POST |
| `/api/skills` | 技能管理 | GET, POST |
| `/api/threads/{thread_id}/artifacts` | 工件管理 | GET |
| `/api/threads/{thread_id}/uploads` | 上传管理 | POST |
| `/api/threads/{thread_id}` | 线程管理 | DELETE |
| `/api/agents` | 代理管理 | GET, POST |
| `/api/threads/{thread_id}/suggestions` | 建议生成 | GET |
| `/api/channels` | 通道管理 | GET, POST |
| `/api/assistants` | 助手兼容 API | GET, POST |
| `/api/runs` | 运行管理 | POST |
| `/health` | 健康检查 | GET |

### 4.2 数据流

1. **用户输入**：用户在前端输入消息或上传文件
2. **API 调用**：前端通过 API 调用后端服务
3. **代理处理**：后端代理处理用户请求，执行工具调用
4. **结果返回**：后端将处理结果返回给前端
5. **前端显示**：前端显示处理结果，包括文本、代码、图像等

## 5. 数据存储

### 5.1 后端存储

- **SQLite**：用于存储线程数据、检查点和状态
- **文件系统**：用于存储上传的文件和生成的工件

### 5.2 前端存储

- **LocalStorage**：用于存储用户设置和会话数据
- **SessionStorage**：用于存储临时会话数据

## 6. 核心功能模块

### 6.1 代理系统

- **代理创建**：基于模型和工具创建代理
- **中间件集成**：通过中间件增强代理功能
- **状态管理**：管理代理的状态和上下文

### 6.2 工具系统

- **内置工具**：包括文件操作、网络请求等基本工具
- **社区工具**：包括搜索、图像处理等扩展工具
- **自定义工具**：支持用户自定义工具

### 6.3 沙箱系统

- **安全执行**：在沙箱中安全执行代码
- **文件操作**：支持文件的创建、读取、修改和删除
- **网络访问**：支持有限的网络访问

### 6.4 内存系统

- **短期记忆**：存储对话历史和上下文
- **长期记忆**：存储重要信息和知识
- **记忆检索**：根据上下文检索相关记忆

### 6.5 通道系统

- **飞书集成**：支持飞书消息收发
- **Slack 集成**：支持 Slack 消息收发
- **Telegram 集成**：支持 Telegram 消息收发
- **企业微信集成**：支持企业微信消息收发

## 7. 技术栈

### 7.1 后端

- **Python**：主要开发语言
- **FastAPI**：API 网关框架
- **LangGraph**：代理系统框架
- **SQLite**：数据存储
- **Docker**：容器化部署

### 7.2 前端

- **TypeScript**：主要开发语言
- **React**：UI 框架
- **Next.js**：前端框架
- **Tailwind CSS**：样式框架
- **shadcn/ui**：UI 组件库

## 8. 部署方式

### 8.1 Docker 部署

项目提供了 Docker 配置，支持容器化部署：

- **Dockerfile**：定义了后端和前端的 Docker 镜像
- **docker-compose.yml**：定义了多容器部署配置
- **nginx 配置**：提供了反向代理和 CORS 支持

### 8.2 本地部署

项目支持本地开发和部署：

- **后端**：使用 Python 虚拟环境和 uvicorn 运行
- **前端**：使用 Next.js 开发服务器运行

## 9. 总结

DeerFlow 是一个功能强大的 AI 代理系统，基于 LangGraph 构建，提供了完整的前端和后端实现。它支持多种功能，包括代理管理、工具集成、沙箱执行、内存管理和通道集成等。通过模块化的设计和丰富的中间件系统，DeerFlow 提供了灵活可扩展的 AI 代理能力，适合各种应用场景。

### 9.1 核心优势

- **模块化设计**：清晰的代码结构和模块化设计，便于扩展和维护
- **丰富的中间件**：提供了多种中间件，增强了代理的功能
- **安全的沙箱**：支持在安全的环境中执行代码
- **多通道集成**：支持与多种即时通讯平台集成
- **完整的前端**：提供了美观易用的前端界面

### 9.2 应用场景

- **智能助手**：提供智能对话和任务执行能力
- **代码开发**：辅助代码编写和调试
- **数据分析**：分析和处理数据
- **内容生成**：生成各种类型的内容
- **自动化任务**：执行各种自动化任务

## 10. 后续发展建议

1. **性能优化**：进一步优化系统性能，支持更大规模的并发请求
2. **扩展工具**：增加更多的内置工具和社区工具
3. **增强安全性**：进一步加强系统的安全性，特别是沙箱执行环境
4. **改进用户体验**：优化前端界面，提供更好的用户体验
5. **支持更多模型**：支持更多的 AI 模型和提供商
6. **增强内存系统**：改进内存管理和检索能力
7. **支持更多通道**：集成更多的即时通讯平台
8. **提供更多文档**：完善系统文档，便于用户理解和使用

---

通过本分析文档，您应该对 DeerFlow 项目的代码结构、功能模块和工作原理有了全面的了解。这将有助于您在后续的开发和修改中快速熟悉项目，提高开发效率。