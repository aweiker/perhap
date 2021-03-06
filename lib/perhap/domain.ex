defmodule Perhap.Domain do
  @callback reducer(atom(), term(), Perhap.Event.t) :: { term(), list(Perhap.Event.t)}

  defmacro __using__(_) do
    quote location: :keep do
      require Logger
      use GenServer, restart: :temporary

      @behaviour Perhap.Domain

      @before_compile unquote(__MODULE__)

      # Interface

      #@spec reduce(service_id: Perhap.Event.UUIDv4.t | module(),
      #             event: list(Perhap.Event.t) | Perhap.Event.t) :: :ok
      def reduce(service_id, event) when not is_list(event), do: reduce(service_id, List.wrap(event))
      def reduce(service_id, events) do
        GenServer.cast({:via, :swarm, service_id}, {:reduce, events})
      end

      @spec retrieve(name: term(), args: map()) :: term()
      def retrieve(name, args \\ %{}) do
        GenServer.call({:via, :swarm, name}, {:retrieve, args})
      end

      # Overridable functions

      @spec reducer(atom(), term(), Perhap.Event.t) :: { term(), list(Perhap.Event.t) }
      def reducer(_event_type, model, _event) do
        Logger.error("[perhap] No reducer defined in module #{__MODULE__}.")
        { model, [] }
      end

      #@spec retriever(state: term(), args: map()) :: { :ok, term() } | { :error, String.t }
      # (CompileError) test/support/perhaptest_fixture.exs:17: spec for undefined function retriever/1
      # Arity 1? Nah.
      def retriever(state, _args), do: {:ok, state}

      defoverridable([reducer: 3, retriever: 2])

      # Setup

      def terminate(reason, state) do
        super(reason, state)
      end

      # Callbacks

      def child_spec(name) do
        %{ super(name) | id: name }
      end

      @spec start_service(term()) :: {:ok, pid()}
      def start_service(name) do
        {:ok, pid} = Swarm.register_name(name, Supervisor, :start_child, [{:via, :swarm, :perhap}, child_spec(name)])
        Swarm.join(:perhap, pid)
        {:ok, pid}
      end

      def ensure_started(name) do
        case Swarm.whereis_name(name) do
          :undefined -> start_service(name)
          pid -> {:ok, pid}
        end
      end

      def init(state) do
        Process.flag(:trap_exit, true)
        {:ok, state}
      end

      # Calls and Casts for Perhap
      def handle_call({:retrieve, args}, _from, state) do
        reply = retriever(state, args)
        { :reply, reply, state }
      end
      def handle_call({:swarm, :begin_handoff}, _from, state) do
        {:reply, {:resume, state}, state}
      end
      def handle_call(req, from, state) do
        super(req, from, state)
      end

      def handle_cast({:reduce, events}, state) do
        { model, new_events } = Enum.reduce( events,
                                             {state, []},
                                             fn event, { state, _new_events } ->
                                               reducer(event.metadata.type, state, event)
                                             end )
        # todo: publish new events
        {:noreply, model}
      end
      def handle_cast({:swarm, :end_handoff, state}, _) do
        {:noreply, state}
      end
      def handle_cast({:swarm, :resolve_conflict, _state}, state) do
        # ignore
        {:noreply, state}
      end
      def handle_cast(req, state) do
        super(req, state)
      end

      def handle_info(:timeout, state) do
        {:stop, :normal, state}
      end
      def handle_info({:swarm, :die}, state) do
        {:stop, :shutdown, state}
      end

    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def start_link(name) do
        GenServer.start_link(__MODULE__, %__MODULE__{}, [name])
      end

      def stop(name) do
        GenServer.stop(name)
      end
    end
  end

end
