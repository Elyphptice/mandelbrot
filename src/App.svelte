<script script lang="ts">
	import { onMount } from "svelte";
	import shader from "./shaders/mandelbrot.wgsl";

	let canvas: HTMLCanvasElement;

	async function init() {
		function exit() {
			console.error(
				'No GPU adapter found! Try enabling the experimental flag "#enable-unsafe-webgpu" under "chrome://flags"'
			);
			return;
		}

		if (!navigator.gpu) exit();
		const adapter = await navigator.gpu.requestAdapter();
		if (!adapter) exit();
		const device = await adapter.requestDevice();
		const context = canvas.getContext("webgpu");

		const pixelRatio = window.devicePixelRatio || 1;
		const presentationSize = [
			canvas.clientWidth * pixelRatio,
			canvas.clientHeight * pixelRatio,
		];
		// @ts-ignore
		const presentationFormat = navigator.gpu.getPreferredCanvasFormat();

		context.configure({
			device,
			format: presentationFormat,
			size: presentationSize,
		});

		const shaderModule = device.createShaderModule({
			code: shader,
		});

		const pipeline = device.createRenderPipeline({
			// @ts-ignore
			layout: "auto",
			vertex: {
				module: shaderModule,
				entryPoint: "vs_main",
			},
			fragment: {
				module: shaderModule,
				entryPoint: "fs_main",
				targets: [
					{
						format: presentationFormat,
					},
				],
			},
			primitive: {
				topology: "triangle-strip",
			},
		});

		class InputData {
			zoom: number;
			x: number;
			y: number;
			r_mod: number;
			g_mod: number;
			b_mod: number;

			constructor() {
				this.zoom = 0;
				this.x = 0;
				this.y = 0;
				this.r_mod = Math.random() * 3;
				this.b_mod = Math.random() * 3;
				this.g_mod = Math.random() * 3;
			}
		}

		const inputBufferSize = 6 * 4;
		const inputBuffer = device.createBuffer({
			size: inputBufferSize,
			usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
		});

		const inputBindGroup = device.createBindGroup({
			layout: pipeline.getBindGroupLayout(0),
			entries: [
				{
					binding: 0,
					resource: {
						buffer: inputBuffer,
					},
				},
			],
		});

		let inputData = new InputData();

		var pressedKeys: string[] = [];

		function frame() {
			if (!context) return;

			document.addEventListener("keydown", (e) => {
				if (!pressedKeys.includes(e.key))
					pressedKeys.push(e.key.toLowerCase());
			});
			document.addEventListener("keyup", (e) => {
				pressedKeys.splice(pressedKeys.indexOf(e.key), 1);
			});

			const speed = 0.01;
			const zoomSpeed = speed;
			const moveSpeed = speed / Math.pow(Math.E, inputData.zoom);

			if (pressedKeys.includes("w")) {
				inputData.y += moveSpeed;
			}
			if (pressedKeys.includes("s")) {
				inputData.y -= moveSpeed;
			}
			if (pressedKeys.includes("d")) {
				inputData.x += moveSpeed;
			}
			if (pressedKeys.includes("a")) {
				inputData.x -= moveSpeed;
			}
			if (pressedKeys.includes("+")) {
				inputData.zoom += zoomSpeed;
			}
			if (pressedKeys.includes("-")) {
				inputData.zoom -= zoomSpeed;
			}
			if (pressedKeys.includes("1")) {
				inputData.r_mod += zoomSpeed;
			}
			if (pressedKeys.includes("2")) {
				inputData.r_mod -= zoomSpeed;
			}
			if (pressedKeys.includes("3")) {
				inputData.g_mod += zoomSpeed;
			}
			if (pressedKeys.includes("4")) {
				inputData.g_mod -= zoomSpeed;
			}
			if (pressedKeys.includes("5")) {
				inputData.b_mod += zoomSpeed;
			}
			if (pressedKeys.includes("6")) {
				inputData.b_mod -= zoomSpeed;
			}
			if (pressedKeys.includes("r")) {
				inputData = new InputData();
			}

			const commandEncoder = device.createCommandEncoder();

			device.queue.writeBuffer(
				inputBuffer,
				0,
				new Float32Array(
					Object.entries(inputData).map(([key, value]) => value)
				)
			);

			const textureView = context.getCurrentTexture().createView();

			const renderPassDescriptor: GPURenderPassDescriptor = {
				colorAttachments: [
					{
						view: textureView,
						clearValue: { r: 0.0, g: 0.0, b: 0.0, a: 1.0 },
						loadOp: "clear",
						storeOp: "store",
					},
				],
			};

			const passEncoder =
				commandEncoder.beginRenderPass(renderPassDescriptor);
			passEncoder.setPipeline(pipeline);
			passEncoder.setBindGroup(0, inputBindGroup);
			passEncoder.draw(4);
			passEncoder.end();

			device.queue.submit([commandEncoder.finish()]);
			requestAnimationFrame(frame);
		}

		requestAnimationFrame(frame);
	}

	onMount(() => {
		init();
	});

	init();
</script>

<canvas bind:this={canvas} />

<style>
	canvas {
		width: 100%;
		height: 100%;
	}
</style>
