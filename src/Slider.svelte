<script lang="ts">
    import { createEventDispatcher } from 'svelte';

    const dispatch = createEventDispatcher();
    export let startValue = 0;
    
    function change(event) {
        dispatch('slide', {
			value: event.target.value / 100
		});
    }
</script>

<div class="slidecontainer">
    <input on:input="{change}" type="range" min="0" max="100" value="{startValue}" class="slider" id="myRange">
</div>

<style>
    .slidecontainer {
        display: flex;
    }
    
    div {
        pointer-events: all;
        color: white;
        mix-blend-mode: difference;
    }
    input[type='range'] {
      overflow: hidden;
      width: 80px;
      -webkit-appearance: none;
      background-color: white;
      mix-blend-mode: exclusion;
    }
    
    input[type='range']::-webkit-slider-runnable-track {
      height: 10px;
      -webkit-appearance: none;
      color: white;
      margin-top: -1px;
    }
    
    input[type='range']::-webkit-slider-thumb {
      width: 10px;
      -webkit-appearance: none;
      height: 10px;
      cursor: ew-resize;
      background: black;
      box-shadow: -80px 0 0 80px white;
    }

</style>