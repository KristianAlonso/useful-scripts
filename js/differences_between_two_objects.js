(function diffs(obj, obj2) {
    return Object.keys(Object.assign({}, obj || {}, obj2 || {})).map(function (key) {
        return key
    }).filter(function (key) {
        return !_.isEqual(obj[key], obj2[key])
    }).reduce(function (differences, key) {
        if (_.isEqual(obj[key], obj2[key])) {
            differences[key] = null
        } else if ([null, undefined].includes(obj[key]) && ![null, undefined].includes(obj2[key])) {
            differences[key] = [obj[key], obj2[key]]
        } else if (![null, undefined].includes(obj[key]) && [null, undefined].includes(obj2[key])) {
            differences[key] = [obj[key], obj2[key]]
        } else if (typeof obj[key] === 'object' && typeof obj2[key] === 'object') {
            differences[key] = diffs(obj[key], obj2[key])
        } else {
            differences[key] = [obj[key], obj2[key]]
        }

        return differences
    }, {})
})(vm.invoice, vm.invoiceInitialValue)