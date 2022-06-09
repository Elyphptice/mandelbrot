<script lang="ts">
	import { onMount } from "svelte";
	import shader from "./shaders/raymarching.wgsl";
	import postShader from "./shaders/post.wgsl";
	import { mat3, mat4, vec2, vec3, vec4 } from "gl-matrix";
import Slider from "./Slider.svelte";

		class Camera {
			public fieldOfView: number;
			public aspectRatio: number;
			public near: number;
			public far: number;
		}

		function createPerpective(camera: Camera) {
			var projection = new Float32Array(16);	
			let top = Math.tan(camera.fieldOfView * Math.PI / 360);
			let right = camera.aspectRatio * top;
			
			projection[0] = 1.0 / right;
			projection[5] = 1.0 / top;
			projection[10] = camera.far / (camera.far - camera.near);
			projection[14] = -(camera.far * camera.near) / (camera.far - camera.near);
			projection[11] = 1.0;
			return projection;
		}

		function randomColor() {
			return vec4.fromValues(Math.random(), Math.random(), Math.random(), 1.0);
		}

		function randomColors(): [vec4, vec4, vec4] {
			return [
					randomColor(),
					randomColor(),
					randomColor()
				];
		}
		
		class InputData {
			x: number;
			y: number;
			z: number;
			// projection: mat4;
			projection: Float32Array;
			mouse: vec2;

			color: number;
			noise: number;
			chromaticAberration: number;
			normals: number;

			iterations: number;
			power: number;

			randomness: number;
			wobble: number;
			seed: number;

			colors: [vec4, vec4, vec4];

			constructor() {
				this.x = 0;
				this.y = 0;
				this.z = 2;
				this.color = 0;
				this.noise = .15;
				this.chromaticAberration = .25;
				this.normals = 0.0;

				this.iterations = 10;
				this.power = 8;

				this.randomness = 0.0;
				this.wobble = 0.0;

				this.seed = Math.random() * 100.0;

				this.colors = randomColors();

				const camera = new Camera();
				camera.aspectRatio = canvas.clientWidth / canvas.clientHeight;
				camera.fieldOfView = 45;
				camera.near = 0.1;
				camera.far = 100;

				this.mouse = vec2.create();
				
				this.projection = createPerpective(camera);
			}
		}

	let inputData: InputData;
	let canvas: HTMLCanvasElement;
	
	let webgpuCapable = false;
	
	async function init() {
		function exit() {
			console.error("No GPU adapter found! Try enabling the experimental flag \"#enable-unsafe-webgpu\" under \"chrome://flags\"");
		}


		if (navigator.gpu == undefined) {
			exit();
			return;
		}

		const adapter = await navigator.gpu.requestAdapter();
		if(!adapter)
			exit();

		webgpuCapable = true;

  		const device = await adapter.requestDevice();
		const context = canvas.getContext('webgpu');

		const pixelRatio = window.devicePixelRatio || 1;
		const presentationSize = [
			canvas.clientWidth * pixelRatio,
			canvas.clientHeight * pixelRatio
		];
		const presentationFormat = context.getPreferredFormat(adapter);

		context.configure({
			device,
			format: presentationFormat,
			size: presentationSize
		});

		const shaderModule = device.createShaderModule({
			code: shader,
		});

		const postShaderModule = device.createShaderModule({
			code: postShader,
		});
		
		const frameBufferTexture = device.createTexture({
			size: presentationSize,
			format: presentationFormat,
			usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.COPY_DST,
		});

		const sampler = device.createSampler({
			magFilter: 'linear',
			minFilter: 'linear',
		});

		const postPipeline = device.createRenderPipeline({
			vertex: {
				module: postShaderModule,
				entryPoint: 'vs_main',
			},
			fragment: {
				module: postShaderModule,
				entryPoint: 'fs_main',
				targets: [
					{
						format: presentationFormat,
					}
				]
			},
			primitive: {
				topology: 'triangle-strip',
			},
		});

		const pipeline = device.createRenderPipeline({
			vertex: {
				module: shaderModule,
				entryPoint: 'vs_main',
			},
			fragment: {
				module: shaderModule,
				entryPoint: 'fs_main',
				targets: [
					{
						format: presentationFormat,
					}
				]
			},
			primitive: {
				topology: 'triangle-strip',
			}
		});

		function multiply(point: Float32Array, mat: Float32Array) {
			var result = new Float32Array(4);
			result[0] = point[0] * mat[0] + point[1] * mat[1] + point[2] * mat[2] + point[3] * mat[3];
			result[1] = point[0] * mat[4] + point[1] * mat[5] + point[2] * mat[6] + point[3] * mat[7];
			result[2] = point[0] * mat[8] + point[1] * mat[9] + point[2] * mat[10] + point[3] * mat[11];
			result[3] = point[0] * mat[12] + point[1] * mat[13] + point[2] * mat[14] + point[3] * mat[15];
			return result;
		}
		
		const inputBufferSize = 304;
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
				}
			]
		});

		const postBindGroup = device.createBindGroup({
			layout: postPipeline.getBindGroupLayout(0),
			entries: [
				{
					binding: 0,
					resource: sampler,
				},
				{
					binding: 1,
					resource: frameBufferTexture.createView(),
				},
				{
					binding: 2,
					resource: {
						buffer: inputBuffer,
					},
				}
			]
		});

		var pressedKeys: { [id: string] : boolean } = {};

		var startTime = performance.now();


		// onclick
		canvas.addEventListener("click", (e) => {
			var havePointerLock = 'pointerLockElement' in document ||
			'mozPointerLockElement' in document ||
			'webkitPointerLockElement' in document;
			
			canvas.requestPointerLock = canvas.requestPointerLock 
			// @ts-ignore
			|| canvas.webkitRequestPointerLock || canvas.mozRequestPointerLock;
		
			canvas.requestPointerLock();
		});

		document.addEventListener("mousemove", moveCallback, false);


		
		function moveCallback(e) {
			if(document.pointerLockElement === canvas ||
				document.mozPointerLockElement === canvas ||
				document.webkitPointerLockElement === canvas) {
				var movementX = e.movementX ||
					e.mozMovementX          ||
					e.webkitMovementX       ||
					0,
				movementY = e.movementY ||
					e.mozMovementY      ||
					e.webkitMovementY   ||
					0;
	
				inputData.mouse[0] += movementX;
				inputData.mouse[1] += movementY;
			}
		}

		document.addEventListener("keydown", (e) => {
			pressedKeys[e.key] = true;
		});
		document.addEventListener("keyup", (e) => {
			pressedKeys[e.key] = false;
		});

		window.addEventListener("resize", () => {
			const camera = new Camera();
				camera.aspectRatio = canvas.clientWidth / canvas.clientHeight;
				camera.fieldOfView = 45;
				camera.near = 0.1;
				camera.far = 100;
			
			inputData.projection = createPerpective(camera);
		});
		
		function frame() {
			if(!context) return;

			
			//#region input
			const speed = .01;

			let input = vec3.create();
			
			if(pressedKeys["w"]) {
				input[2] -= speed;
			}
			if(pressedKeys["s"]) {
				input[2] += speed;
			}
			if(pressedKeys["d"]) {
				input[0] -= speed;
			}
			if(pressedKeys["a"]) {
				input[0] += speed;
			}
			if(pressedKeys["e"]) {
				input[1] -= speed;
			}
			if(pressedKeys["q"]) {
				input[1] += speed;
			}
			if(pressedKeys["r"]) {
				// inputData = new InputData();
			}

			
			//#endregion
			
			const commandEncoder = device.createCommandEncoder();
			
			var projection = mat4.fromValues(
				inputData.projection[0], inputData.projection[1], inputData.projection[2], inputData.projection[3],
				inputData.projection[4], inputData.projection[5], inputData.projection[6], inputData.projection[7],
				inputData.projection[8], inputData.projection[9], inputData.projection[10], inputData.projection[11],
				inputData.projection[12], inputData.projection[13], inputData.projection[14], inputData.projection[15]
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
			
			device.queue.writeBuffer(inputBuffer, 64, new Float32Array(inverseProjection));
			device.queue.writeBuffer(inputBuffer, 128, new Float32Array(inverseView));
			device.queue.writeBuffer(inputBuffer, 192, new Float32Array([inputData.x, inputData.y, inputData.z]));
			device.queue.writeBuffer(inputBuffer, 204, new Float32Array([
				currentTime, inputData.color, inputData.noise, inputData.chromaticAberration, 
				inputData.iterations, inputData.power, inputData.normals, inputData.randomness, inputData.wobble,
				inputData.seed,
			]));
			let offset = 10 * 4;
			device.queue.writeBuffer(inputBuffer, 204 + offset, new Float32Array(inputData.colors[0]));
			device.queue.writeBuffer(inputBuffer, 204 + offset + 16, new Float32Array(inputData.colors[1]));
			device.queue.writeBuffer(inputBuffer, 204 + offset + 32, new Float32Array(inputData.colors[2]));


			const textureView = context.getCurrentTexture().createView();

			const renderPassDescriptor: GPURenderPassDescriptor = {
				colorAttachments: [
					{
						view: frameBufferTexture.createView(),
						clearValue: { r: 0.0, g: 0.0, b: 0.0, a: 1.0 },
						loadOp: 'clear',
						storeOp: 'store',
					},
				],
			};

			const postRenderPassDescriptor: GPURenderPassDescriptor = {
				colorAttachments: [
					{
						view: textureView,
						clearValue: { r: 0.0, g: 0.0, b: 0.0, a: 1.0 },
						loadOp: 'clear',
						storeOp: 'store',
					},
				],
			};

			const passEncoder = commandEncoder.beginRenderPass(renderPassDescriptor);
			passEncoder.setPipeline(pipeline);
			passEncoder.setBindGroup(0, inputBindGroup);
			passEncoder.draw(4);
			passEncoder.end();
			
			const postPassEncoder = commandEncoder.beginRenderPass(postRenderPassDescriptor);
			postPassEncoder.setPipeline(postPipeline);
			postPassEncoder.setBindGroup(0, postBindGroup);
			postPassEncoder.draw(4);
			postPassEncoder.end();

			device.queue.submit([commandEncoder.finish()]);
			requestAnimationFrame(frame);
		}

		requestAnimationFrame(frame);
	}

	function getFrustumCorners(camera: Camera): mat4{
		const fov = camera.fieldOfView;
		const aspect = camera.aspectRatio;

		const fovTan = Math.tan(fov * 0.5 * Math.PI / 180);

		let frustomCorners = mat4.create();

		const toRight = vec3.fromValues(fovTan * aspect, 0, 0);
		const toTop = vec3.fromValues(0, fovTan * aspect, 0);

		frustomCorners = setRow(frustomCorners, 0, add(backward, neg(toRight), toTop)); // top-left
		frustomCorners = setRow(frustomCorners, 1, add(backward, toRight, toTop)); // top-right
		frustomCorners = setRow(frustomCorners, 2, add(backward, toRight, neg(toTop))); // bottom-right
		frustomCorners = setRow(frustomCorners, 3, add(backward, neg(toRight), neg(toTop))); // bottom-left

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
		inputData = new InputData();
	});
</script>

{#if webgpuCapable}
	<div>
		<span>
			<Slider startValue={50} on:slide={(v) => inputData.iterations = v.detail.value * 20}></Slider>
			<h6>iteration_count</h6>
		</span>
		<span>
			<Slider startValue={16} on:slide={(v) => inputData.power = v.detail.value * 50}></Slider>
			<h6>fractal_power</h6>
		</span>
		<span>
			<Slider startValue={0} on:slide={(v) => inputData.color = v.detail.value}></Slider>
			<h6>color</h6>
			<h6 on:click="{() => inputData.colors = randomColors()}" class="bg-inverse">[randomize]</h6>
		</span>
		<span>
			<Slider startValue={15} on:slide={(v) => inputData.noise = v.detail.value}></Slider>
			<h6>noise</h6>
		</span>
	</div>
	<div class="right">
		<span>
			<Slider startValue={25} on:slide={(v) => inputData.chromaticAberration = v.detail.value}></Slider>
			<h6>chromatic_abberation</h6>
		</span>
		<span>
			<Slider startValue={0} on:slide={(v) => inputData.normals = v.detail.value}></Slider>
			<h6>normal_strenght</h6>
		</span>
		<span>
			<Slider startValue={0} on:slide={(v) => inputData.randomness = v.detail.value / 10}></Slider>
			<h6>randomness</h6>
			<h6 on:click="{() => inputData.seed = Math.random() * 100.0}" class="bg-inverse">[reseed]</h6>
		</span>
		<span>
			<Slider startValue={0} on:slide={(v) => inputData.wobble = v.detail.value / 20}></Slider>
			<h6>wobble_speed</h6>
		</span>
	</div>
	<div style="width: 100vw; display: flex; justify-content: center;">
		<h6 style="margin-top: 12px;">webgpu_mandelbulb_explorer</h6>
	</div>
	<h6 style="position: absolute; bottom: 0">
		|<br>
		|<br>
		+--
	</h6>
	<h6 style="position: absolute; bottom: 0; right: 0; text-align: right;">
		|<br>
		|<br>
		--+
	</h6>
	<h6 style="position: absolute; bottom: 0; width: 100vw; text-align: center; margin: 0; transform: translateY(-10px)">
		- x -
	</h6>
	
{:else}
	<h6 style="color: black; justify-content: center; align-items: center; display: flex; height: 100vh">
		No GPU adapter found! Try updating chrome and enabling the experimental flag "#enable-unsafe-webgpu" under "chrome://flags.
	</h6>
{/if}
<canvas bind:this="{canvas}">
</canvas>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Press+Start+2P&display=swap" rel="stylesheet">
<style>
	.bg-inverse {
		pointer-events: all;
		padding: 2px;
		background-color: #00000000;
		color: white;
	}
	.bg-inverse:hover {
		background-color: #fff;
		color: #000;
		cursor: pointer;
	}
	h6 {
		font-family: 'Press Start 2P', cursive;
		font-size: 10px;
		margin: 10px;
		margin-top: 12px;
		color: white;
		mix-blend-mode: difference;
	}
	span {
		margin-top: -10px;
		margin-left: 10px;
		display:flex; align-items: center;
	}
	canvas {
		width: 100vw;
		height: 100vh;
	}
	div {
		pointer-events: none;
		height: 100vh;
		position: absolute;
	}
	div > :nth-child(1) {
		margin-top: 5px;
	}
	.right {
		right: 0;
		margin-right: 10px;
	}
	.right span {
		flex-direction: row-reverse;
	}
</style>
