(() => {
    const seed = [['Amarillo', 'Blanco'], ['S', 'M'], ['Casual', 'Deportivo'], ['Camisa', 'Camiseta']]

    function buildCombinations (array, combineWith = []) {
        const [items, ...left] = array
        const result = []

        if (!items) return [combineWith]

        for (const item of items) {
            let combined = [...combineWith, item]

            if (left.length) result.push(...buildCombinations(left, combined))
            else result.push(combined)
        }

        return result
    }

    return buildCombinations(seed)
})()
