<script lang="ts">
	import { onMount } from "svelte";
	import shader from "./shaders/raymarching.wgsl";
	import { mat3, mat4, vec2, vec3 } from "gl-matrix";

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
			x: number;
			y: number;
			z: number;
			// projection: mat4;
			projection: Float32Array;
			mouse: vec2;

			constructor() {
				this.x = 0;
				this.y = 0;
				this.z = 2;

				const camera = new Camera();
				camera.aspectRatio = canvas.width / canvas.height;
				camera.fieldOfView = 45;
				camera.near = 0.1;
				camera.far = 100;

				this.mouse = vec2.create();

				this.projection = createPerpective(camera);
			}
		}

		function createPerpective(camera: Camera) {
			var projection = new Float32Array(16);
			let top = Math.tan((camera.fieldOfView * Math.PI) / 360);
			let right = camera.aspectRatio * top;

			projection[0] = 1.0 / right;
			projection[5] = 1.0 / top;
			projection[10] = camera.far / (camera.far - camera.near);
			projection[14] =
				-(camera.far * camera.near) / (camera.far - camera.near);
			projection[11] = 1.0;
			return projection;
		}

		function multiply(point: Float32Array, mat: Float32Array) {
			var result = new Float32Array(4);
			result[0] =
				point[0] * mat[0] +
				point[1] * mat[1] +
				point[2] * mat[2] +
				point[3] * mat[3];
			result[1] =
				point[0] * mat[4] +
				point[1] * mat[5] +
				point[2] * mat[6] +
				point[3] * mat[7];
			result[2] =
				point[0] * mat[8] +
				point[1] * mat[9] +
				point[2] * mat[10] +
				point[3] * mat[11];
			result[3] =
				point[0] * mat[12] +
				point[1] * mat[13] +
				point[2] * mat[14] +
				point[3] * mat[15];
			return result;
		}

		const inputBufferSize = 208;
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

		var pressedKeys: { [id: string]: boolean } = {};

		var startTime = performance.now();

		// onclick
		canvas.addEventListener("click", (e) => {
			var havePointerLock =
				"pointerLockElement" in document ||
				"mozPointerLockElement" in document ||
				"webkitPointerLockElement" in document;

			canvas.requestPointerLock =
				canvas.requestPointerLock ||
				// @ts-ignore
				canvas.webkitRequestPointerLock ||
				canvas.mozRequestPointerLock;

			canvas.requestPointerLock();
		});

		document.addEventListener("mousemove", moveCallback, false);

		function moveCallback(e) {
			var movementX =
					e.movementX || e.mozMovementX || e.webkitMovementX || 0,
				movementY =
					e.movementY || e.mozMovementY || e.webkitMovementY || 0;

			inputData.mouse[0] += movementX;
			inputData.mouse[1] += movementY;
		}

		document.addEventListener("keydown", (e) => {
			pressedKeys[e.key] = true;
		});
		document.addEventListener("keyup", (e) => {
			pressedKeys[e.key] = false;
		});

		function frame() {
			if (!context) return;

			//#region input

			const speed = 0.01;

			let input = vec3.create();

			if (pressedKeys["w"]) {
				input[2] -= speed;
			}
			if (pressedKeys["s"]) {
				input[2] += speed;
			}
			if (pressedKeys["d"]) {
				input[0] -= speed;
			}
			if (pressedKeys["a"]) {
				input[0] += speed;
			}
			if (pressedKeys["e"]) {
				input[1] -= speed;
			}
			if (pressedKeys["q"]) {
				input[1] += speed;
			}
			if (pressedKeys["r"]) {
				// inputData = new InputData();
			}

			//#endregion

			const commandEncoder = device.createCommandEncoder();

			var projection = mat4.fromValues(
				inputData.projection[0],
				inputData.projection[1],
				inputData.projection[2],
				inputData.projection[3],
				inputData.projection[4],
				inputData.projection[5],
				inputData.projection[6],
				inputData.projection[7],
				inputData.projection[8],
				inputData.projection[9],
				inputData.projection[10],
				inputData.projection[11],
				inputData.projection[12],
				inputData.projection[13],
				inputData.projection[14],
				inputData.projection[15]
			);

			var view = mat4.create();
			mat4.rotate(view, view, inputData.mouse[0] / 1000, [0, 1, 0]);
			mat4.rotate(view, view, inputData.mouse[1] / 300, [1, 0, 0]);

			let inverseView = mat4.create();
			mat4.invert(inverseView, view);

			let y = input[1];
			input[1] = 0;

			vec3.transformMat4(input, input, view);

			inputData.x += input[0];
			inputData.y += y;
			inputData.z += input[2];

			// mat4.translate(view, view, [inputData.x, inputData.y, inputData.z]);

			let inverseProjection = mat4.create();
			mat4.invert(inverseProjection, projection);

			mat4.multiply(projection, projection, view);

			device.queue.writeBuffer(inputBuffer, 0, new Float32Array(view));

			var currentTime = performance.now();
			currentTime = (currentTime - startTime) / 1000;

			device.queue.writeBuffer(
				inputBuffer,
				64,
				new Float32Array(inverseProjection)
			);
			device.queue.writeBuffer(
				inputBuffer,
				128,
				new Float32Array(inverseView)
			);
			device.queue.writeBuffer(
				inputBuffer,
				192,
				new Float32Array([inputData.x, inputData.y, inputData.z])
			);
			device.queue.writeBuffer(
				inputBuffer,
				204,
				new Float32Array([currentTime])
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

	class Camera {
		public fieldOfView: number;
		public aspectRatio: number;
		public near: number;
		public far: number;
	}

	function getFrustumCorners(camera: Camera): mat4 {
		const fov = camera.fieldOfView;
		const aspect = camera.aspectRatio;

		const fovTan = Math.tan((fov * 0.5 * Math.PI) / 180);

		let frustomCorners = mat4.create();

		const toRight = vec3.fromValues(fovTan * aspect, 0, 0);
		const toTop = vec3.fromValues(0, fovTan * aspect, 0);

		frustomCorners = setRow(
			frustomCorners,
			0,
			add(backward, neg(toRight), toTop)
		); // top-left
		frustomCorners = setRow(
			frustomCorners,
			1,
			add(backward, toRight, toTop)
		); // top-right
		frustomCorners = setRow(
			frustomCorners,
			2,
			add(backward, toRight, neg(toTop))
		); // bottom-right
		frustomCorners = setRow(
			frustomCorners,
			3,
			add(backward, neg(toRight), neg(toTop))
		); // bottom-left

		return frustomCorners;
	}

	const backward = vec3.fromValues(0, 0, -1);

	function setRow(matrix: mat4, row: number, vec: vec3) {
		matrix[row] = vec[0];
		matrix[row + 4] = vec[1];
		matrix[row + 8] = vec[2];
		return matrix;
	}

	function add(a: vec3, b: vec3, c: vec3) {
		vec3.add(a, a, b);
		vec3.add(a, a, c);
		return a;
	}

	function neg(vec: vec3) {
		vec3.negate(vec, vec);
		return vec;
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
